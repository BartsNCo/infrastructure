const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const { MongoClient } = require('mongodb');

let cachedDb = null;

async function getMongoConnection() {
    if (cachedDb && cachedDb.topology && cachedDb.topology.isConnected()) {
        console.log('Using cached database connection');
        return cachedDb;
    }
    
    try {
        // Retrieve secret from AWS Secrets Manager
        const client = new SecretsManagerClient({ region: process.env.AWS_REGION });
        const command = new GetSecretValueCommand({
            SecretId: process.env.MONGODB_SECRET_ARN
        });
        
        console.log('Retrieving MongoDB secret from Secrets Manager...');
        const response = await client.send(command);
        const secret = JSON.parse(response.SecretString);
        
        console.log('Connecting to MongoDB...');
        const mongoClient = new MongoClient(secret.MONGODB_URI, {
            serverSelectionTimeoutMS: 5000,
            connectTimeoutMS: 10000,
            tls: true,
            tlsCAFile: '/var/task/global-bundle.pem',
        });
        
        await mongoClient.connect();
        console.log('Successfully connected to MongoDB');
        
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
    
    console.log('Unity Builder Lambda triggered');
    console.log('Event:', JSON.stringify(event, null, 2));
    
    try {
        // Test MongoDB connection
        const db = await getMongoConnection();
        console.log('MongoDB connection test: SUCCESS');
        
        // List collections as additional verification
        const collections = await db.listCollections().toArray();
        console.log('Available collections:', collections.map(c => c.name));
        
        // Process each S3 record
        for (const record of event.Records) {
            const eventName = record.eventName;
            const bucketName = record.s3.bucket.name;
            const objectKey = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
            const objectSize = record.s3.object.size;
            
            console.log(`Processing ${eventName} for object ${objectKey} in bucket ${bucketName}`);
            console.log(`Object size: ${objectSize} bytes`);
            
            // TODO: Add Unity asset building logic here
            console.log(`Would process Unity asset for: ${objectKey}`);
        }
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: 'Unity Builder Lambda completed successfully',
                recordsProcessed: event.Records.length,
                mongodbConnected: true
            })
        };
    } catch (error) {
        console.error('Lambda execution failed:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({
                message: 'Unity Builder Lambda failed',
                error: error.message,
                mongodbConnected: false
            })
        };
    }
};