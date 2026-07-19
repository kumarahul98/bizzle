import {defineConfig} from 'sanity'
import {structureTool} from 'sanity/structure'
import {visionTool} from '@sanity/vision'
import {schemaTypes} from './schemaTypes'

export default defineConfig({
  name: 'default',
  title: 'Traevy',

  projectId: '4ylvs0zh',
  dataset: 'production',

  plugins: [structureTool(), visionTool()],

  schema: {
    types: schemaTypes,
  },
  
  document: {
    productionUrl: async (prev, context) => {
      const { document } = context
      if (document._type === 'post' && document.slug?.current) {
        const isLocalhost = typeof window !== 'undefined' && window.location.hostname === 'localhost'
        const baseUrl = isLocalhost ? 'http://localhost:5173' : 'https://bizzle.pages.dev' // Replace with final prod URL if different
        return `${baseUrl}/preview/${document.slug.current}`
      }
      return prev
    }
  }
})
