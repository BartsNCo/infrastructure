const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const secretsManager = new SecretsManagerClient();

exports.handler = async (event) => {
    console.log('Full authentication event:', JSON.stringify(event, null, 2));
    
    // Transfer Family sends the event in a specific format
    const username = event.username;
    const password = event.password;
    const serverId = event.serverId;
    const protocol = event.protocol;
    const sourceIp = event.sourceIp;
    
    console.log('Parsed credentials - Username:', username, 'ServerId:', serverId, 'Protocol:', protocol);
    
    if (!username || !password) {
        console.log('Missing username or password');
        return {};
    }
    
    try {
        // Get credentials from Secrets Manager
        console.log('Fetching secret from:', process.env.SECRETS_MANAGER_SECRET_ID);
        const command = new GetSecretValueCommand({
            SecretId: process.env.SECRETS_MANAGER_SECRET_ID
        });
        const secretData = await secretsManager.send(command);
        
        const credentials = JSON.parse(secretData.SecretString);
        console.log('Secret fetched successfully. Expected username:', credentials.username);
        
        // Verify credentials
        if (username === credentials.username && password === credentials.password) {
            const response = {
                Role: process.env.USER_ROLE_ARN,
                HomeDirectoryType: 'PATH',
                HomeDirectory: '/' + process.env.S3_BUCKET_NAME,
                Policy: ''  // Empty policy means use the role's policy
            };
            
            console.log('Authentication successful. Response:', JSON.stringify(response, null, 2));
            return response;
        } else {
            console.log('Authentication failed. Username match:', username === credentials.username, 'Password match:', password === credentials.password);
            return {};
        }
    } catch (error) {
        console.error('Error during authentication:', error);
        console.error('Error stack:', error.stack);
        return {};
    }
};
