const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const { S3Client, ListObjectsV2Command } = require('@aws-sdk/client-s3');
const { EC2Client, StartInstancesCommand, DescribeInstancesCommand } = require('@aws-sdk/client-ec2');
const { SSMClient, SendCommandCommand, GetCommandInvocationCommand } = require('@aws-sdk/client-ssm');
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

async function waitForInstanceRunning(ec2Client, instanceId, maxRetries = 30) {
    for (let i = 0; i < maxRetries; i++) {
        const describeCommand = new DescribeInstancesCommand({
            InstanceIds: [instanceId]
        });
        
        const response = await ec2Client.send(describeCommand);
        const instance = response.Reservations[0]?.Instances[0];
        
        if (instance?.State?.Name === 'running') {
            return true;
        }
        
        // Wait 10 seconds before next check
        await new Promise(resolve => setTimeout(resolve, 10000));
    }
    
    return false;
}

async function waitForInstanceStopped(ec2Client, instanceId, maxRetries = 30) {
    for (let i = 0; i < maxRetries; i++) {
        const describeCommand = new DescribeInstancesCommand({
            InstanceIds: [instanceId]
        });
        
        const response = await ec2Client.send(describeCommand);
        const instance = response.Reservations[0]?.Instances[0];
        
        if (instance?.State?.Name === 'stopped') {
            return true;
        }
        
        // Wait 10 seconds before next check
        await new Promise(resolve => setTimeout(resolve, 10000));
    }
    
    return false;
}

async function executeCommand(ssmClient, instanceId, commands) {
    const sendCommand = new SendCommandCommand({
        InstanceIds: [instanceId],
        DocumentName: 'AWS-RunShellScript',
        Parameters: {
            commands: commands
        },
        TimeoutSeconds: 3600 // 1 hour timeout
    });
    
    const commandResponse = await ssmClient.send(sendCommand);
    const commandId = commandResponse.Command.CommandId;
    
    // Wait for command to complete
    let commandStatus = 'InProgress';
    let retries = 0;
    const maxRetries = 360; // 30 minutes with 5 second intervals
    
    while (commandStatus === 'InProgress' && retries < maxRetries) {
        await new Promise(resolve => setTimeout(resolve, 5000)); // Wait 5 seconds
        
        const getCommand = new GetCommandInvocationCommand({
            CommandId: commandId,
            InstanceId: instanceId
        });
        
        try {
            const invocationResponse = await ssmClient.send(getCommand);
            commandStatus = invocationResponse.Status;
            
            if (commandStatus === 'Success') {
                return {
                    success: true,
                    output: invocationResponse.StandardOutputContent,
                    error: invocationResponse.StandardErrorContent
                };
            } else if (commandStatus === 'Failed' || commandStatus === 'Cancelled' || commandStatus === 'TimedOut') {
                return {
                    success: false,
                    output: invocationResponse.StandardOutputContent,
                    error: invocationResponse.StandardErrorContent
                };
            }
        } catch (error) {
            if (error.name !== 'InvocationDoesNotExist') {
                throw error;
            }
        }
        
        retries++;
    }
    
    return {
        success: false,
        error: 'Command timed out after 30 minutes'
    };
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
                    console.log(tour);
                    console.log(pano);
                    if (pano.unityUrl) {
                        allPanosFromTours.push({
                            tourId: tour._id,
                            tourName: tour.name,
                            panoId: pano._id || pano.id,
                            unityUrl: pano.unityUrl,
                            panoName: pano.name,
                            audioKey: pano.audio || null,
                            thumbnailKey: tour.thumbnailKey || null
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
        
        // Process with EC2 instance
        if (matchingPanos.length === 0) {
            const result = { matchingPanos: 0, instanceStarted: false };
            console.log(JSON.stringify(result, null, 2));
            return { statusCode: 200, body: JSON.stringify(result) };
        }
        
        const ec2Client = new EC2Client({ region: process.env.AWS_REGION });
        const ssmClient = new SSMClient({ region: process.env.AWS_REGION });
        
        try {
            // Check if instance is already running
            const describeCommand = new DescribeInstancesCommand({
                InstanceIds: [process.env.EC2_INSTANCE_ID]
            });
            
            const instanceResponse = await ec2Client.send(describeCommand);
            const instance = instanceResponse.Reservations[0]?.Instances[0];
            const instanceState = instance?.State?.Name;
            
            if (instanceState !== 'running') {
                // If instance is stopping, wait for it to stop first
                if (instanceState === 'stopping') {
                    console.log(`Instance is stopping, waiting for it to stop completely...`);
                    const isStopped = await waitForInstanceStopped(ec2Client, process.env.EC2_INSTANCE_ID);
                    
                    if (!isStopped) {
                        throw new Error('Instance failed to reach stopped state within timeout');
                    }
                    console.log(`Instance has stopped`);
                }
                
                // Start the EC2 instance
                const startCommand = new StartInstancesCommand({
                    InstanceIds: [process.env.EC2_INSTANCE_ID]
                });
                
                await ec2Client.send(startCommand);
                console.log(`Started EC2 instance: ${process.env.EC2_INSTANCE_ID}`);
                
                // Wait for instance to be running
                const isRunning = await waitForInstanceRunning(ec2Client, process.env.EC2_INSTANCE_ID);
                
                if (!isRunning) {
                    throw new Error('Instance failed to reach running state within timeout');
                }
                
                console.log('Instance is running, waiting 2 minutes for SSM agent to be ready...');
                await new Promise(resolve => setTimeout(resolve, 120000)); // 2 minutes
            } else {
                return {
                    statusCode: 200,
                    body: JSON.stringify({message: "There is a process running already. Will not run it again."})
                };
            }
            
            // Save matching panos to file instead of environment variable
            const panosData = {
                panos: matchingPanos,
                count: matchingPanos.length,
                timestamp: new Date().toISOString()
            };
            
            // Execute the update.sh script as ubuntu user with background logging
            const commands = [
                `echo '${JSON.stringify(panosData)}' > /home/ubuntu/panos_data.json`,
                'chown ubuntu:ubuntu /home/ubuntu/panos_data.json',
                'chmod 644 /home/ubuntu/panos_data.json',
                'su - ubuntu -c "nohup bash /home/ubuntu/update.sh &"',
                'echo "Script started in background as ubuntu user, check /home/ubuntu/logs-unity-builder/ for logs"'
            ];
            
            console.log('Executing update.sh script...');
            const sendCommand = new SendCommandCommand({
                InstanceIds: [process.env.EC2_INSTANCE_ID],
                DocumentName: 'AWS-RunShellScript',
                Parameters: {
                    commands: commands
                },
                TimeoutSeconds: 3600 // 1 hour timeout
            });
            
            const commandResponse = await ssmClient.send(sendCommand);
            console.log(`Command sent successfully. Command ID: ${commandResponse.Command.CommandId}`);
            
            const result = {
                matchingPanos: matchingPanos.length,
                instanceWasRunning: instanceState === 'running',
                instanceStarted: instanceState !== 'running',
                instanceId: process.env.EC2_INSTANCE_ID,
                scriptExecuted: true,
                commandId: commandResponse.Command.CommandId
            };
            
            console.log(JSON.stringify(result, null, 2));
            
            return {
                statusCode: 200,
                body: JSON.stringify(result)
            };
        } catch (error) {
            console.error('Failed to start EC2 instance or execute script:', error.message);
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
