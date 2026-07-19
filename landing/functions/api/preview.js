export async function onRequest(context) {
  const { request, env } = context;
  const url = new URL(request.url);
  const slug = url.searchParams.get('slug');

  if (!slug) {
    return new Response(JSON.stringify({ error: 'Missing slug' }), { status: 400 });
  }

  // Ensure SANITY_VIEWER_TOKEN is set in your Cloudflare Pages dashboard
  const token = env.SANITY_VIEWER_TOKEN;
  if (!token) {
    return new Response(JSON.stringify({ error: 'Server configuration error' }), { status: 500 });
  }

  const query = encodeURIComponent(`*[_type == "post" && slug.current == "${slug}"] | order(_updatedAt desc)[0]{
    ...,
    author->
  }`);
  
  const projectId = '4ylvs0zh';
  const dataset = 'production';
  const apiVersion = '2024-01-01';
  
  const sanityUrl = `https://${projectId}.api.sanity.io/v${apiVersion}/data/query/${dataset}?query=${query}&perspective=drafts`;

  try {
    const sanityResponse = await fetch(sanityUrl, {
      headers: {
        Authorization: `Bearer ${token}`
      }
    });
    
    if (!sanityResponse.ok) {
      throw new Error('Failed to fetch from Sanity');
    }

    const data = await sanityResponse.json();
    
    return new Response(JSON.stringify(data), {
      headers: { 'Content-Type': 'application/json' }
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
}
