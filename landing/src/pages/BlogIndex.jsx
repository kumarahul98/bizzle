import React, { useEffect, useState, useContext } from 'react'
import { Link } from 'react-router-dom'
import { Head as Helmet } from 'vite-react-ssg'
import { client } from '../lib/sanity'
import { ThemeCtx } from '../theme'
import { Container } from '../components/ui.jsx'

const ComingSoonAnimation = ({ t }) => {
  return (
    <div style={{
      marginTop: 40,
      padding: '80px 40px',
      borderRadius: 24,
      background: t.bgElev,
      border: `1px solid ${t.border}`,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      textAlign: 'center',
      position: 'relative',
      overflow: 'hidden'
    }}>
      <style>
        {`
          @keyframes cursor-blink {
            0%, 100% { opacity: 1; }
            50% { opacity: 0; }
          }
          @keyframes slide-right {
            0% { transform: translateX(-100%); }
            100% { transform: translateX(200%); }
          }
        `}
      </style>
      <div style={{
         position: 'absolute', top: 0, left: 0, right: 0, height: 2,
         background: t.surface2, overflow: 'hidden'
      }}>
         <div style={{
           width: '50%', height: '100%', background: t.moving,
           animation: 'slide-right 2.5s ease-in-out infinite'
         }}/>
      </div>
      
      <div style={{
        width: 56, height: 56, borderRadius: 28, background: t.surface,
        border: `1px solid ${t.borderStr}`, display: 'flex', alignItems: 'center', justifyContent: 'center',
        marginBottom: 24
      }}>
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={t.textDim} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M12 19l7-7 3 3-7 7-3-3z"></path>
          <path d="M18 13l-1.5-7.5L2 2l3.5 14.5L13 18l5-5z"></path>
          <path d="M2 2l7.586 7.586"></path>
          <circle cx="11" cy="11" r="2"></circle>
        </svg>
      </div>

      <h2 style={{ fontSize: '24px', fontWeight: 600, color: t.text, letterSpacing: '-0.02em', marginBottom: 12 }}>
        Stories from the commute<span style={{ display: 'inline-block', width: 9, height: 22, background: t.text, marginLeft: 6, animation: 'cursor-blink 1s step-end infinite', verticalAlign: 'middle' }}/>
      </h2>
      <p style={{ maxWidth: 420, color: t.textDim, fontSize: '15.5px', lineHeight: 1.6, margin: 0 }}>
        We are preparing our first set of articles on traffic patterns, remote work data, and reclaiming your lost hours.
      </p>
    </div>
  )
}

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
    }).catch(() => {
      // Handle network or configuration errors gracefully
      setPosts([])
      setLoading(false)
    })
  }, [])

  return (
    <Container width={800} style={{ padding: '80px 32px 120px' }}>
      <Helmet>
        <title>Blog | Traevy</title>
        <meta name="description" content="Read our latest insights on commuting, time management, and more." />
      </Helmet>
      
      <h1 style={{ fontSize: '3rem', margin: 0, fontWeight: 700, letterSpacing: '-0.04em', color: t.text }}>Blog</h1>
      
      {loading ? (
        <div style={{ marginTop: 40, color: t.textDim }}>Loading...</div>
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
                  style={{ display: 'block', marginBottom: '16px', color: t.textMuted, fontSize: '0.9rem' }}
                >
                  {new Date(post.publishedAt).toLocaleDateString('en-US', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric'
                  })}
                </time>
              )}
              {post.excerpt && <p style={{ color: t.textDim, lineHeight: 1.6 }}>{post.excerpt}</p>}
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
          
          {posts.length === 0 && <ComingSoonAnimation t={t} />}
        </div>
      )}
    </Container>
  )
}
