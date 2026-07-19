import { createClient } from '@sanity/client'
import createImageUrlBuilder from '@sanity/image-url'

export const projectId = '4ylvs0zh'
export const dataset = 'production'
export const apiVersion = '2024-01-01'

export const client = createClient({
  projectId,
  dataset,
  apiVersion,
  useCdn: true,
  perspective: 'published',
})

const builder = createImageUrlBuilder(client)

export function urlFor(source) {
  return builder.image(source)
}
