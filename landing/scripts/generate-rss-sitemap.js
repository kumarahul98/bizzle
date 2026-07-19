import fs from 'fs'
import path from 'path'
import { createClient } from '@sanity/client'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const distDir = path.resolve(__dirname, '../dist')

const client = createClient({
  projectId: '4ylvs0zh',
  dataset: 'production',
  apiVersion: '2024-01-01',
  useCdn: true,
  perspective: 'published',
})

const BASE_URL = 'https://traevy.com'

async function generate() {
  const posts = await client.fetch(`
    *[_type == "post" && defined(slug.current)] | order(publishedAt desc) {
      title,
      slug,
      excerpt,
      publishedAt,
      _updatedAt
    }
  `)

  // 1. Generate sitemap.xml
  const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>${BASE_URL}/</loc>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>${BASE_URL}/blog</loc>
    <changefreq>daily</changefreq>
    <priority>0.8</priority>
  </url>
  ${posts.map(post => `
  <url>
    <loc>${BASE_URL}/blog/${post.slug.current}</loc>
    <lastmod>${new Date(post._updatedAt || post.publishedAt || new Date()).toISOString()}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>
  `).join('')}
</urlset>`

  fs.writeFileSync(path.join(distDir, 'sitemap.xml'), sitemap)

  // 2. Generate RSS Feed
  const rss = `<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
  <title>Traevy Blog</title>
  <link>${BASE_URL}/blog</link>
  <description>Insights on commuting, time management, and taking your day back.</description>
  ${posts.map(post => `
  <item>
    <title><![CDATA[${post.title}]]></title>
    <link>${BASE_URL}/blog/${post.slug.current}</link>
    <guid>${BASE_URL}/blog/${post.slug.current}</guid>
    ${post.publishedAt ? `<pubDate>${new Date(post.publishedAt).toUTCString()}</pubDate>` : ''}
    <description><![CDATA[${post.excerpt || ''}]]></description>
  </item>
  `).join('')}
</channel>
</rss>`

  fs.writeFileSync(path.join(distDir, 'feed.xml'), rss)

  console.log(`Generated sitemap.xml and feed.xml with ${posts.length} posts.`)
}

generate().catch(console.error)
