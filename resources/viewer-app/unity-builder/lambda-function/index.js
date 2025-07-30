const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const { S3Client, ListObjectsV2Command } = require('@aws-sdk/client-s3');
const { ECSClient, RunTaskCommand } = require('@aws-sdk/client-ecs');
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
        const s3Keys = s3Files.map(file => file.Key.replace('image/', ''));
        
        // Get all tours and check their panos
        const toursCollection = db.collection('tours');
        const allTours = await toursCollection.find({}).toArray();
        let allPanosFromTours = [];
        
        allTours.forEach(tour => {
            if (tour.panos && Array.isArray(tour.panos)) {
                tour.panos.forEach(pano => {
                    if (pano.s3Key) {
                        allPanosFromTours.push({
                            tourId: tour._id,
                            tourName: tour.name,
                            panoId: pano._id || pano.id,
                            s3Key: pano.s3Key,
                            panoName: pano.name
                        });
                    }
                });
            }
        });
        
        // Find matching panos
        const matchingPanos = allPanosFromTours.filter(pano => {
            const panoKey = pano.s3Key.replace('image/', '').replace('.jpg', '');
            return s3Keys.includes(panoKey) || 
                   s3Keys.includes(pano.s3Key) ||
                   s3Keys.includes(pano.s3Key.replace('image/', ''));
        });
        
        // Launch a single ECS task with all matching panos
        if (matchingPanos.length === 0) {
            const result = { matchingPanos: 0, tasksLaunched: 0 };
            console.log(JSON.stringify(result, null, 2));
            return { statusCode: 200, body: JSON.stringify(result) };
        }
        
        const ecsClient = new ECSClient({ region: process.env.AWS_REGION });
        
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