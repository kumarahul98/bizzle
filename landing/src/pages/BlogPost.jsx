import React, { useEffect, useState, useContext } from 'react'
import { useParams, Link } from 'react-router-dom'
import { Head as Helmet } from 'vite-react-ssg'
import { PortableText } from '@portabletext/react'
import { client, urlFor } from '../lib/sanity'
import { ThemeCtx } from '../theme'

export function BlogPost() {
  const { slug } = useParams()
  const [post, setPost] = useState(null)
  const [loading, setLoading] = useState(true)
  const { t } = useContext(ThemeCtx)

  useEffect(() => {
    client.fetch(`
      *[_type == "post" && slug.current == $slug][0] {
        title,
        slug,
        mainImage,
        body,
        publishedAt,
        _updatedAt,
        excerpt,
        seo,
        author->{
          name,
          image
        }
      }
    `, { slug }).then(data => {
      setPost(data)
      setLoading(false)
    })
  }, [slug])

  if (loading) {
    return <main style={{ maxWidth: '800px', margin: '0 auto', padding: '120px 24px' }}>Loading...</main>
  }

  if (!post) {
    return <main style={{ maxWidth: '800px', margin: '0 auto', padding: '120px 24px' }}>
      <h1>Post not found</h1>
      <Link to="/blog">← Back to blog</Link>
    </main>
  }

  // --- SEO & Metadata Parsing ---
  const currentUrl = `https://traevy.com/blog/${post.slug.current}`
  const seoTitle = post.seo?.metaTitle || `${post.title} | Traevy Blog`
  const seoDesc = post.seo?.metaDescription || post.excerpt || ''
  
  // Images
  const ogImage = post.seo?.ogImage 
    ? urlFor(post.seo.ogImage).width(1200).height(630).url() 
    : (post.mainImage ? urlFor(post.mainImage).width(1200).height(630).url() : null)
    
  // JSON-LD Structured Data
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    "mainEntityOfPage": {
      "@type": "WebPage",
      "@id": currentUrl
    },
    "headline": post.seo?.metaTitle || post.title,
    "description": seoDesc,
    "image": ogImage ? [ogImage] : [],
    "datePublished": post.publishedAt || post._updatedAt,
    "dateModified": post._updatedAt,
    "author": post.author ? {
      "@type": "Person",
      "name": post.author.name,
      "url": "https://traevy.com" 
    } : {
      "@type": "Organization",
      "name": "Traevy"
    },
    "publisher": {
      "@type": "Organization",
      "name": "Traevy",
      "logo": {
        "@type": "ImageObject",
        "url": "https://traevy.com/favicon.png"
      }
    }
  }

  const portableTextComponents = {
    types: {
      image: ({ value }) => {
        if (!value?.asset?._ref) return null
        return (
          <img
            alt={value.alt || post.title}
            loading="lazy"
            src={urlFor(value).width(800).fit('max').auto('format').url()}
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
        <title>{seoTitle}</title>
        {seoDesc && <meta name="description" content={seoDesc} />}
        
        {/* Canonical Link */}
        <link rel="canonical" href={post.seo?.canonicalUrl || currentUrl} />
        
        {/* Robots */}
        {post.seo?.noIndex && <meta name="robots" content="noindex, nofollow" />}
        
        {/* Open Graph */}
        <meta property="og:type" content="article" />
        <meta property="og:title" content={seoTitle} />
        {seoDesc && <meta property="og:description" content={seoDesc} />}
        <meta property="og:url" content={currentUrl} />
        {ogImage && <meta property="og:image" content={ogImage} />}
        
        {/* Twitter */}
        <meta name="twitter:card" content="summary_large_image" />
        <meta name="twitter:title" content={seoTitle} />
        {seoDesc && <meta name="twitter:description" content={seoDesc} />}
        {ogImage && <meta name="twitter:image" content={ogImage} />}
        
        {/* Keywords */}
        {post.seo?.keywords?.length > 0 && (
          <meta name="keywords" content={post.seo.keywords.join(', ')} />
        )}
        
        {/* JSON-LD Structured Data */}
        <script type="application/ld+json">
          {JSON.stringify(jsonLd)}
        </script>
      </Helmet>

      <Link to="/blog" style={{ color: t.muted, textDecoration: 'none', display: 'inline-block', marginBottom: '32px' }}>
        ← Back to all posts
      </Link>

      <article>
        <header style={{ marginBottom: '48px' }}>
          <h1 style={{ fontSize: '3rem', fontWeight: 800, lineHeight: 1.2, marginBottom: '24px' }}>
            {post.title}
          </h1>
          
          <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
            {post.author?.image && (
              <img 
                src={urlFor(post.author.image).width(48).height(48).url()} 
                alt={post.author.name}
                style={{ width: '48px', height: '48px', borderRadius: '50%', objectFit: 'cover' }}
              />
            )}
            <div>
              {post.author && <div style={{ fontWeight: 600 }}>{post.author.name}</div>}
              {post.publishedAt && (
                <time dateTime={post.publishedAt} style={{ color: t.muted, fontSize: '0.9rem' }}>
                  {new Date(post.publishedAt).toLocaleDateString('en-US', {
                    year: 'numeric', month: 'long', day: 'numeric'
                  })}
                </time>
              )}
            </div>
          </div>
        </header>

        {post.mainImage && (
          <img 
            src={urlFor(post.mainImage).width(800).height(450).url()} 
            alt={post.mainImage.alt || post.title}
            style={{ width: '100%', height: 'auto', borderRadius: '12px', marginBottom: '48px' }}
          />
        )}

        <div style={{ paddingBottom: '60px' }}>
          {post.body ? (
            <PortableText value={post.body} components={portableTextComponents} />
          ) : (
            <p>No content found.</p>
          )}
        </div>
      </article>
    </main>
  )
}
