module.exports = {
  projects: [
    {
      displayName: 'unit',
      preset: 'ts-jest',
      testEnvironment: 'node',
      testMatch: ['<rootDir>/src/utils/__tests__/**/*.test.ts'],
    },
    // Plan 03 appends an `integration` project here (test/**/*.test.ts, emulator
    // setupFiles, maxWorkers:1). It MUST keep this `unit` project intact so
    // `npm run test:unit` (--selectProjects unit) still discovers the util tests.
  ],
};
