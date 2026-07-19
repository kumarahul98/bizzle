import { createClient } from '@sanity/client'
import createImageUrlBuilder from '@sanity/image-url'
import { projectId, dataset, apiVersion } from './sanity'

// This client is strictly for use in routes/functions where the 
// viewer token can be injected securely (e.g., Cloudflare Pages Functions),
// or for authenticated preview routes.
export const previewClient = createClient({
  projectId,
  dataset,
  apiVersion,
  useCdn: false,
  perspective: 'drafts',
  // In a real app, this token comes from an environment variable on the server.
  // For Cloudflare pages, this should be fetched from a serverless function, 
  // or injected carefully if we are doing a purely client-side SPA preview route.
  // DO NOT HARDCODE YOUR TOKEN HERE.
})

const builder = createImageUrlBuilder(previewClient)

export function urlForPreview(source) {
  return builder.image(source)
}
