import React from 'react'
import { AppLayout } from './App.jsx'
import { Home } from './pages/Home.jsx'
import { BlogIndex } from './pages/BlogIndex.jsx'
import { BlogPost } from './pages/BlogPost.jsx'
import { BlogPreview } from './pages/BlogPreview.jsx'
import { client } from './lib/sanity.js'

export const routes = [
  {
    path: '/',
    element: <AppLayout />,
    children: [
      {
        index: true,
        element: <Home />
      },
      {
        path: 'blog',
        element: <BlogIndex />
      },
      {
        path: 'blog/:slug',
        element: <BlogPost />,
        // This tells vite-react-ssg which slugs to fetch and prerender at build time
        getStaticPaths: async () => {
          const slugs = await client.fetch(`*[_type == "post" && defined(slug.current)][].slug.current`)
          return slugs.map(slug => `blog/${slug}`)
        }
      },
      {
        path: 'preview/:slug',
        element: <BlogPreview />
        // Note: No getStaticPaths here because previews should stay client-side and dynamic
      }
    ]
  }
]
