import {defineCliConfig} from 'sanity/cli'

export default defineCliConfig({
  api: {
    projectId: '4ylvs0zh',
    dataset: 'production'
  },
  studioHost: 'traevy',
  deployment: {
    appId: 'c7mudnrkno8jx02g4o8se537',
    /**
     * Enable auto-updates for studios.
     * Learn more at https://www.sanity.io/docs/studio/latest-version-of-sanity#k47faf43faf56
     */
    autoUpdates: true,
  },
})
