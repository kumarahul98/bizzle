import React, { useEffect, useState, useContext } from 'react'
import { Link } from 'react-router-dom'
import { Head as Helmet } from 'vite-react-ssg'
import { client } from '../lib/sanity'
import { ThemeCtx } from '../theme'

export function BlogIndex() {
  const [posts, setPosts] = useState([])
  const [loading, setLoading] = useState(true)
  const { t } = useContext(ThemeCtx)

  useEffect(() => {
    client.fetch(`
      *[_type == "post"] | order(publishedAt desc) {
        _id,
        title,
        slug,
        excerpt,
        publishedAt
      }
    `).then(data => {
      setPosts(data)
      setLoading(false)
    })
  }, [])

  return (
    <main style={{ maxWidth: '800px', margin: '0 auto', padding: '120px 24px 60px' }}>
      <Helmet>
        <title>Blog | Traevy</title>
        <meta name="description" content="Read our latest insights on commuting, time management, and more." />
      </Helmet>
      
      <h1 style={{ fontSize: '3rem', marginBottom: '40px', fontWeight: 700 }}>Blog</h1>
      
      {loading ? (
        <p>Loading posts...</p>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '40px' }}>
          {posts.map(post => (
            <article key={post._id} style={{ padding: '24px', border: `1px solid ${t.border}`, borderRadius: '12px' }}>
              <h2 style={{ fontSize: '1.5rem', marginBottom: '12px' }}>
                <Link 
                  to={`/blog/${post.slug.current}`}
                  style={{ color: t.text, textDecoration: 'none' }}
                >
                  {post.title}
                </Link>
              </h2>
              {post.publishedAt && (
                <time 
                  dateTime={post.publishedAt}
                  style={{ display: 'block', marginBottom: '16px', color: t.muted, fontSize: '0.9rem' }}
                >
                  {new Date(post.publishedAt).toLocaleDateString('en-US', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric'
                  })}
                </time>
              )}
              {post.excerpt && <p style={{ color: t.muted, lineHeight: 1.6 }}>{post.excerpt}</p>}
              <Link 
                to={`/blog/${post.slug.current}`} 
                style={{ 
                  display: 'inline-block', 
                  marginTop: '16px', 
                  color: t.accent || '#F59E0B',
                  fontWeight: 600,
                  textDecoration: 'none'
                }}
              >
                Read more →
              </Link>
            </article>
          ))}
          {posts.length === 0 && <p>No posts found.</p>}
        </div>
      )}
    </main>
  )
}
