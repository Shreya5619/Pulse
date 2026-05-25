const neo4j = require('neo4j-driver');
require('dotenv').config({ path: 'c:/Pulse/.env' });

console.log('Testing Neo4j connection...');
console.log('URI: bolt://localhost:7687');
console.log('User:', process.env.NEO4J_USER);

const driver = neo4j.driver(
    'bolt://localhost:7687',
    neo4j.auth.basic(process.env.NEO4J_USER, process.env.NEO4J_PASSWORD)
);

// We will try connecting to the database 'neo4j' (standard for local Community Edition)
const session = driver.session({ database: 'neo4j' });

session.run('RETURN 1 AS val')
    .then(result => {
        console.log('Success! Connected to local Neo4j database.');
        console.log('Result:', result.records[0].get('val').toString());
        session.close();
        driver.close();
    })
    .catch(err => {
        console.error('Connection failed to local Neo4j:', err.message);
        
        // Let's try with default user/password 'neo4j/pulse_guardian' in case docker was started differently
        console.log('Trying with fallback credentials neo4j / pulse_guardian...');
        const driverFallback = neo4j.driver(
            'bolt://localhost:7687',
            neo4j.auth.basic('neo4j', 'pulse_guardian')
        );
        const sessionFallback = driverFallback.session({ database: 'neo4j' });
        sessionFallback.run('RETURN 1 AS val')
            .then(result => {
                console.log('Success with fallback credentials!');
                sessionFallback.close();
                driverFallback.close();
                driver.close();
            })
            .catch(err2 => {
                console.error('Fallback also failed:', err2.message);
                driverFallback.close();
                driver.close();
            });
    });
