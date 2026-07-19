import React, { useEffect, useState, useContext } from 'react'
import { useParams, Link } from 'react-router-dom'
import { Head as Helmet } from 'vite-react-ssg'
import { PortableText } from '@portabletext/react'
import { urlForPreview } from '../lib/sanityPreview'
import { ThemeCtx } from '../theme'

export function BlogPreview() {
  const { slug } = useParams()
  const [post, setPost] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const { t } = useContext(ThemeCtx)

  useEffect(() => {
    // We hit our serverless function instead of exposing the token directly to the client
    fetch(`/api/preview?slug=${slug}`)
      .then(res => {
        if (!res.ok) throw new Error('Failed to fetch preview')
        return res.json()
      })
      .then(data => {
        if (data.error) throw new Error(data.error)
        // Ensure we got an array with a result or the direct result object
        const finalData = Array.isArray(data.result) ? data.result[0] : (data.result || data)
        setPost(finalData)
        setLoading(false)
      })
      .catch(err => {
        console.error(err)
        setError(err.message)
        setLoading(false)
      })
  }, [slug])

  if (loading) {
    return <main style={{ maxWidth: '800px', margin: '0 auto', padding: '120px 24px' }}>Loading Preview...</main>
  }

  if (error || !post) {
    return (
      <main style={{ maxWidth: '800px', margin: '0 auto', padding: '120px 24px' }}>
        <h1>Preview Error</h1>
        <p>{error || 'Draft not found.'}</p>
        <Link to="/blog">← Back to blog</Link>
      </main>
    )
  }

  // Same styling components as BlogPost
  const portableTextComponents = {
    types: {
      image: ({ value }) => {
        if (!value?.asset?._ref) return null
        return (
          <img
            alt={value.alt || post?.title || ' '}
            loading="lazy"
            src={urlForPreview(value).width(800).fit('max').auto('format').url()}
            style={{ width: '100%', borderRadius: '8px', margin: '32px 0' }}
          />
        )
      }
    },
    marks: {
      link: ({ children, value }) => {
        const rel = !value.href.startsWith('/') ? 'noreferrer noopener' : undefined
        return (
          <a href={value.href} rel={rel} style={{ color: t.accent || '#F59E0B' }}>
            {children}
          </a>
        )
      }
    },
    block: {
      h1: ({ children }) => <h1 style={{ fontSize: '2.5rem', marginTop: '48px', marginBottom: '24px' }}>{children}</h1>,
      h2: ({ children }) => <h2 style={{ fontSize: '2rem', marginTop: '40px', marginBottom: '20px' }}>{children}</h2>,
      h3: ({ children }) => <h3 style={{ fontSize: '1.5rem', marginTop: '32px', marginBottom: '16px' }}>{children}</h3>,
      normal: ({ children }) => <p style={{ fontSize: '1.1rem', lineHeight: 1.8, marginBottom: '24px', color: t.text }}>{children}</p>,
      blockquote: ({ children }) => (
        <blockquote style={{ borderLeft: `4px solid ${t.accent || '#F59E0B'}`, paddingLeft: '24px', marginLeft: 0, fontStyle: 'italic', color: t.muted }}>
          {children}
        </blockquote>
      )
    }
  }

  return (
    <main style={{ maxWidth: '800px', margin: '0 auto', padding: '120px 24px 60px' }}>
      <Helmet>
        <title>Preview: {post.title || 'Draft'}</title>
      </Helmet>

      <div style={{ backgroundColor: '#F59E0B', color: 'white', padding: '8px 16px', borderRadius: '4px', display: 'inline-block', marginBottom: '32px', fontWeight: 'bold' }}>
        DRAFT PREVIEW MODE
      </div>

      <article>
        <header style={{ marginBottom: '48px' }}>
          <h1 style={{ fontSize: '3rem', fontWeight: 800, lineHeight: 1.2, marginBottom: '24px' }}>
            {post.title || 'Untitled Draft'}
          </h1>
          
          <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
            {post.author?.image && (
              <img 
                src={urlForPreview(post.author.image).width(48).height(48).url()} 
                alt={post.author.name}
                style={{ width: '48px', height: '48px', borderRadius: '50%', objectFit: 'cover' }}
              />
            )}
            <div>
              {post.author && <div style={{ fontWeight: 600 }}>{post.author.name}</div>}
              <div style={{ color: t.muted, fontSize: '0.9rem' }}>Unpublished Draft</div>
            </div>
          </div>
        </header>

        {post.mainImage && (
          <img 
            src={urlForPreview(post.mainImage).width(800).height(450).url()} 
            alt={post.mainImage.alt || post.title || 'Hero image'}
            style={{ width: '100%', height: 'auto', borderRadius: '12px', marginBottom: '48px' }}
          />
        )}

        <div style={{ paddingBottom: '60px' }}>
          {post.body ? (
            <PortableText value={post.body} components={portableTextComponents} />
          ) : (
            <p>No content yet.</p>
          )}
        </div>
      </article>
    </main>
  )
}
