import neo4j, { Driver, Session } from 'neo4j-driver';

class Neo4jService {
  private driver: Driver;

  constructor() {
    const uri = process.env.NEO4J_URI || 'bolt://localhost:7687';
    const user = process.env.NEO4J_USER || 'neo4j';
    const password = process.env.NEO4J_PASSWORD || 'pulse_guardian';

    this.driver = neo4j.driver(uri, neo4j.auth.basic(user, password));
  }

  async getSession(database: string = process.env.NEO4J_DB || 'neo4j'): Promise<Session> {
    return this.driver.session({ database });
  }

  async close() {
    await this.driver.close();
  }

  async runQuery(query: string, params: any = {}) {
    const session = await this.getSession();
    try {
      const result = await session.run(query, params);
      return result;
    } finally {
      await session.close();
    }
  }
}

export const neo4jService = new Neo4jService();
