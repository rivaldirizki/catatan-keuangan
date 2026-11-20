import { app } from './app.js';
import { runMigration } from '../database/migrate.js';

const PORT = process.env.PORT || 3000;

async function bootstrap() {
  try {
    await runMigration();
  } catch (err) {
    console.warn('[Startup] Migration note:', err.message);
  }

  app.listen(PORT, () => {
    console.log(`===============================================`);
    console.log(`Finance Backend REST API & Admin running!`);
    console.log(`API Base URL:  http://localhost:${PORT}/api/v1`);
    console.log(`Admin Portal:  http://localhost:${PORT}/admin`);
    console.log(`Health Check:  http://localhost:${PORT}/health`);
    console.log(`===============================================`);
  });
}

bootstrap();
