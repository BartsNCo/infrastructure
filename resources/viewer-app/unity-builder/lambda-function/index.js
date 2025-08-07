const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const { S3Client, ListObjectsV2Command } = require('@aws-sdk/client-s3');
const { ECSClient, RunTaskCommand, ListTasksCommand, DescribeTasksCommand } = require('@aws-sdk/client-ecs');
const { MongoClient } = require('mongodb');

let cachedDb = null;

async function getMongoConnection() {
    if (cachedDb && cachedDb.topology && cachedDb.topology.isConnected()) {
        return cachedDb;
    }
    
    try {
        // Retrieve secret from AWS Secrets Manager
        const client = new SecretsManagerClient({ region: process.env.AWS_REGION });
        const command = new GetSecretValueCommand({
            SecretId: process.env.MONGODB_SECRET_ARN
        });
        
        const response = await client.send(command);
        const secret = JSON.parse(response.SecretString);
        
        const mongoClient = new MongoClient(secret.MONGODB_URI, {
            serverSelectionTimeoutMS: 5000,
            connectTimeoutMS: 10000,
            tls: true,
            tlsCAFile: '/var/task/global-bundle.pem',
        });
        
        await mongoClient.connect();
        
        cachedDb = mongoClient.db();
        return cachedDb;
    } catch (error) {
        console.error('Failed to connect to MongoDB:', error.message);
        throw error;
    }
}

async function checkForPendingTasks(ecsClient) {
    try {
        // List only pending tasks in the cluster
        const listPendingCommand = new ListTasksCommand({
            cluster: process.env.ECS_CLUSTER_NAME,
            desiredStatus: 'PENDING'
        });
        
        const pendingResponse = await ecsClient.send(listPendingCommand);
        
        if (!pendingResponse.taskArns || pendingResponse.taskArns.length === 0) {
            return { hasPendingTasks: false, pendingTasks: [] };
        }
        
        // Get task details to check task definition family
        const describeTasksCommand = new DescribeTasksCommand({
            cluster: process.env.ECS_CLUSTER_NAME,
            tasks: pendingResponse.taskArns
        });
        
        const describeResponse = await ecsClient.send(describeTasksCommand);
        
        // Extract task definition family from ARN
        const taskDefinitionArn = process.env.ECS_TASK_DEFINITION;
        const taskFamily = taskDefinitionArn.split('/')[1].split(':')[0]; // Extract family name
        
        // Check if any pending task is from the same family
        const pendingTasksFromFamily = describeResponse.tasks.filter(task => {
            const taskFamily = task.taskDefinitionArn.split('/')[1].split(':')[0];
            return taskFamily === taskFamily;
        });
        
        return {
            hasPendingTasks: pendingTasksFromFamily.length > 0,
            pendingTasks: pendingTasksFromFamily.map(task => ({
                taskArn: task.taskArn,
                lastStatus: task.lastStatus,
                taskDefinition: task.taskDefinitionArn
            }))
        };
    } catch (error) {
        console.error('Error checking for pending tasks:', error.message);
        return { hasPendingTasks: false, pendingTasks: [] };
    }
}

exports.handler = async (event, context) => {
    // Keep the connection alive between invocations
    context.callbackWaitsForEmptyEventLoop = false;
    
    try {
        // Connect to MongoDB
        const db = await getMongoConnection();
        
        // List all files in S3 bucket's image/ directory
        const s3Client = new S3Client({ region: process.env.AWS_REGION });
        const listCommand = new ListObjectsV2Command({
            Bucket: process.env.BUCKET_NAME,
            Prefix: 'image/'
        });
        
        const s3Response = await s3Client.send(listCommand);
        const s3Files = s3Response.Contents || [];
        
        // Extract just the filenames (remove 'image/' prefix)
        const unityUrls = s3Files.map(file => file.Key.replace('image/', ''));
        
        // Get all tours and check their panos
        const toursCollection = db.collection('tours');
        const allTours = await toursCollection.find({}).toArray();
        let allPanosFromTours = [];
        
        allTours.forEach(tour => {
            if (tour.panos && Array.isArray(tour.panos)) {
                tour.panos.forEach(pano => {
                    if (pano.unityUrl) {
                        allPanosFromTours.push({
                            tourId: tour._id,
                            tourName: tour.name,
                            panoId: pano._id || pano.id,
                            unityUrl: pano.unityUrl,
                            panoName: pano.name
                        });
                    }
                });
            }
        });
        
        // Find matching panos
        const matchingPanos = allPanosFromTours.filter(pano => {
            const panoKey = pano.unityUrl.replace('image/', '').replace('.jpg', '');
            return unityUrls.includes(panoKey) || 
                   unityUrls.includes(pano.unityUrl) ||
                   unityUrls.includes(pano.unityUrl.replace('image/', ''));
        });
        
        // Launch a single ECS task with all matching panos
        if (matchingPanos.length === 0) {
            const result = { matchingPanos: 0, tasksLaunched: 0 };
            console.log(JSON.stringify(result, null, 2));
            return { statusCode: 200, body: JSON.stringify(result) };
        }
        
        const ecsClient = new ECSClient({ region: process.env.AWS_REGION });
        
        // Check for existing pending tasks from the same family
        const taskCheck = await checkForPendingTasks(ecsClient);
        
        if (taskCheck.hasPendingTasks) {
            const result = {
                matchingPanos: matchingPanos.length,
                tasksLaunched: 0,
                message: 'Task not launched - existing pending task found',
                pendingTasks: taskCheck.pendingTasks
            };
            
            console.log(JSON.stringify(result, null, 2));
            
            return {
                statusCode: 200,
                body: JSON.stringify(result)
            };
        }
        
        try {
            const runTaskCommand = new RunTaskCommand({
                cluster: process.env.ECS_CLUSTER_NAME,
                taskDefinition: process.env.ECS_TASK_DEFINITION,
                launchType: 'FARGATE',
                networkConfiguration: {
                    awsvpcConfiguration: {
                        subnets: process.env.ECS_SUBNET_IDS.split(','),
                        securityGroups: [process.env.ECS_SECURITY_GROUP_ID],
                        assignPublicIp: 'ENABLED'
                    }
                },
                overrides: {
                    containerOverrides: [
                        {
                            name: 'unity-builder',
                            environment: [
                                {
                                    name: 'PANOS_JSON',
                                    value: JSON.stringify(matchingPanos)
                                },
                                {
                                    name: 'PANOS_COUNT',
                                    value: matchingPanos.length.toString()
                                }
                            ]
                        }
                    ]
                }
            });
            
            const response = await ecsClient.send(runTaskCommand);
            const taskArn = response.tasks && response.tasks.length > 0 ? response.tasks[0].taskArn : null;
            
            const result = {
                matchingPanos: matchingPanos.length,
                tasksLaunched: taskArn ? 1 : 0,
                taskArn: taskArn
            };
            
            console.log(JSON.stringify(result, null, 2));
            
            return {
                statusCode: 200,
                body: JSON.stringify(result)
            };
        } catch (error) {
            console.error('Failed to launch ECS task:', error.message);
            return {
                statusCode: 500,
                body: JSON.stringify({ error: error.message })
            };
        }
    } catch (error) {
        console.error('Lambda execution failed:', error.message);
        return {
            statusCode: 500,
            body: JSON.stringify({
                error: error.message
            })
        };
    }
};
