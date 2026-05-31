module.exports = {
  projects: [
    {
      displayName: 'unit',
      preset: 'ts-jest',
      testEnvironment: 'node',
      testMatch: ['<rootDir>/src/utils/__tests__/**/*.test.ts'],
    },
    {
      displayName: 'integration',
      preset: 'ts-jest',
      testEnvironment: 'node',
      testMatch: ['<rootDir>/test/**/*.test.ts'],
      setupFiles: ['<rootDir>/test/helpers/emulator.ts'],
      maxWorkers: 1,
      testTimeout: 30000,
    },
  ],
};
