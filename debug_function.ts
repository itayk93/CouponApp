// Replace the users query section (around line 73-77) with this debug version:

// Get all users (for debugging - remove push_token requirement)
const { data: users, error: usersError } = await supabaseClient
  .from('users')
  .select('id, email, first_name, last_name, push_token')
  // .not('push_token', 'is', null)  // Commented out for testing

if (usersError) {
  throw usersError
}

console.log(`👥 Found ${users?.length || 0} total users`)
console.log('Users details:', users?.map(u => ({ id: u.id, email: u.email, has_push_token: !!u.push_token })))

if (!users || users.length === 0) {
  return new Response(
    JSON.stringify({ success: true, message: 'No users found in database' }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}