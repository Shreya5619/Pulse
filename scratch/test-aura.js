const neo4j = require('neo4j-driver');

const uri = 'neo4j+s://10a8724f.databases.neo4j.io';
const user = 'neo4j'; // standard Aura username is usually 'neo4j'
const password = 'WWmyW6ksgYjp9fCb3-HaYam8i-yrebWSVszOGlKoeog';

console.log('Testing connection to Aura Neo4j...');
console.log('URI:', uri);
console.log('User:', user);

const driver = neo4j.driver(uri, neo4j.auth.basic(user, password));
const session = driver.session({ database: 'neo4j' });

session.run('RETURN 1 AS val')
  .then(result => {
    console.log('Success! Connected with user: neo4j');
    console.log('Result:', result.records[0].get('val').toString());
    session.close();
    driver.close();
  })
  .catch(err => {
    console.error('Connection failed with user neo4j:', err.message);
    
    // Try with username '10a8724f' in case that is the username
    console.log('Trying with username: 10a8724f...');
    const driver2 = neo4j.driver(uri, neo4j.auth.basic('10a8724f', password));
    const session2 = driver2.session({ database: 'neo4j' });
    session2.run('RETURN 1 AS val')
      .then(result => {
        console.log('Success! Connected with user: 10a8724f');
        console.log('Result:', result.records[0].get('val').toString());
        session2.close();
        driver2.close();
        driver.close();
      })
      .catch(err2 => {
        console.error('Connection failed with user 10a8724f:', err2.message);
        driver2.close();
        driver.close();
      });
  });
