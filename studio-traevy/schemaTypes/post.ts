import { defineField, defineType, defineArrayMember } from 'sanity'
import { DocumentTextIcon } from '@sanity/icons/DocumentText'

export const post = defineType({
  name: 'post',
  title: 'Post',
  type: 'document',
  icon: DocumentTextIcon,
  groups: [
    { name: 'content', title: 'Content', default: true },
    { name: 'seo', title: 'SEO & Metadata' }
  ],
  fields: [
    defineField({
      name: 'title',
      title: 'Title',
      type: 'string',
      group: 'content',
      validation: (rule) => rule.required(),
    }),
    defineField({
      name: 'slug',
      title: 'Slug',
      type: 'slug',
      group: 'content',
      options: { source: 'title', maxLength: 96 },
      validation: (rule) => rule.required(),
    }),
    defineField({
      name: 'author',
      title: 'Author',
      type: 'reference',
      group: 'content',
      to: [{ type: 'author' }],
    }),
    defineField({
      name: 'mainImage',
      title: 'Main image',
      type: 'image',
      group: 'content',
      options: { hotspot: true },
      fields: [
        defineField({
          name: 'alt',
          type: 'string',
          title: 'Alternative text',
          description: 'Important for SEO and accessibility.',
          validation: (rule) => rule.required().warning('Adding alt text highly improves SEO.'),
        })
      ]
    }),
    defineField({
      name: 'categories',
      title: 'Categories',
      type: 'array',
      group: 'content',
      of: [defineArrayMember({ type: 'string' })],
    }),
    defineField({
      name: 'publishedAt',
      title: 'Published at',
      type: 'datetime',
      group: 'content',
    }),
    defineField({
      name: 'excerpt',
      title: 'Excerpt',
      type: 'text',
      group: 'content',
      description: 'A short summary of the post for the blog index. (Used as fallback for SEO Meta Description)',
    }),
    defineField({
      name: 'body',
      title: 'Body',
      type: 'array',
      group: 'content',
      of: [
        defineArrayMember({ type: 'block' }),
        defineArrayMember({ 
          type: 'image',
          fields: [
            defineField({
              name: 'alt',
              type: 'string',
              title: 'Alternative text',
              description: 'Important for SEO and accessibility.',
            })
          ]
        })
      ],
    }),
    
    // --- SEO GROUP ---
    defineField({
      name: 'seo',
      title: 'SEO Settings',
      type: 'object',
      group: 'seo',
      fields: [
        defineField({ 
          name: 'metaTitle', 
          title: 'Meta Title', 
          type: 'string',
          description: 'Optimal length: 50-60 characters. Overrides the main post title.',
          validation: Rule => Rule.max(60).warning('Longer titles may be truncated by search engines')
        }),
        defineField({ 
          name: 'metaDescription', 
          title: 'Meta Description', 
          type: 'text',
          description: 'Optimal length: 150-160 characters. Overrides the excerpt.',
          validation: Rule => Rule.max(160).warning('Longer descriptions may be truncated by search engines')
        }),
        defineField({ 
          name: 'ogImage', 
          title: 'Social Share Image (Open Graph)', 
          type: 'image',
          description: 'Image displayed when sharing on Twitter/Facebook. (1200x630px recommended). Overrides Main Image.',
        }),
        defineField({ 
          name: 'keywords', 
          title: 'Keywords', 
          type: 'array',
          of: [{type: 'string'}],
          description: 'Target keywords for this post (optional but good for organization).'
        }),
        defineField({ 
          name: 'canonicalUrl', 
          title: 'Canonical URL', 
          type: 'url',
          description: 'If this post was published elsewhere first, paste the original URL here.'
        }),
        defineField({ 
          name: 'noIndex', 
          title: 'Hide from search engines (NoIndex)', 
          type: 'boolean',
          description: 'Toggle on to tell Google NOT to index this page.',
          initialValue: false
        })
      ]
    })
  ],
})
