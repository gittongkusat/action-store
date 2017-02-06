require 'test_helper'

class ActionStore::ModelTest < ActiveSupport::TestCase
  test ".user" do
    monkey = Monkey.new
    assert_equal true, monkey.respond_to?(:user)
  end

  test ".target" do
    monkey = Monkey.new
    assert_equal true, monkey.respond_to?(:target)
  end

  test 'scopes' do
    assert_kind_of ActiveRecord::Relation, Monkey.like_posts
    assert_kind_of ActiveRecord::Relation, Monkey.follow_posts
    assert_kind_of ActiveRecord::Relation, Monkey.follow_users
    assert_kind_of ActiveRecord::Relation, Monkey.star_posts
    assert_kind_of ActiveRecord::Relation, Monkey.like_comments
  end

  test ".find_defined_action" do
    assert_not_equal nil, Monkey.find_defined_action(:like, :post)
    assert_not_equal nil, Monkey.find_defined_action('like', 'post')
    assert_not_equal nil, Monkey.find_defined_action(:follow, 'User')
    assert_not_equal nil, Monkey.find_defined_action(:star, 'post')
    assert_nil Monkey.find_defined_action(:like, :user)

    defined_action = Monkey.find_defined_action(:like, :post)
    assert_equal('like', defined_action[:action_type])
    assert_equal('post', defined_action[:action_name])
    assert_equal(Post, defined_action[:target_klass])
    assert_equal('likes_count', defined_action[:counter_cache])

    defined_action = Monkey.find_defined_action(:follow, :user)
    assert_equal('follow', defined_action[:action_type])
    assert_equal('user', defined_action[:action_name])
    assert_equal(User, defined_action[:target_klass])
    assert_equal('followers_count', defined_action[:counter_cache])
    assert_equal('following_count', defined_action[:user_counter_cache])

    defined_action = Monkey.find_defined_action(:follow, :post)
    assert_equal('follow', defined_action[:action_type])
    assert_equal('post', defined_action[:action_name])
    assert_equal(Post, defined_action[:target_klass])
    assert_nil(defined_action[:counter_cache])
    assert_nil(defined_action[:user_counter_cache])
  end

  test ".create_action bas action_type" do
    a = Monkey.create_action('foobar', {})
    assert_equal false, a
    assert_equal 0, Monkey.count
  end

  test ".create_action" do
    post = create(:post)
    a = Monkey.create_action('like', target: post, user: post.user)
    assert_equal false, a.new_record?
    assert_equal 'like', a.action_type
    assert_equal post.id, a.target_id
    assert_equal 'Post', a.target_type
    assert_equal  post.user_id, a.user_id
    assert_equal 1, Monkey.like_posts.count
    post.reload
    assert_equal 1, post.likes_count

    a_with_option = Monkey.create_action('like', target: post, user: post.user, action_option: 'aaa')
    assert_equal 'aaa', a_with_option.action_option
    assert_equal 1, Monkey.like_posts.count

    b = Monkey.create_action('like', target: post, user: post.user)
    assert_equal false, b.new_record?
    assert_equal a.id, b.id

    c = Monkey.create_action('like', target_type: 'Post', target_id: post.id, user: post.user)
    assert_equal false, c.new_record?
    assert_equal a.id, c.id

    user1 = create(:user)
    a1 = Monkey.create_action('like', target: post, user: user1)
    assert_equal false, a1.new_record?
    assert_not_equal a.id, a1.id
    assert_equal 2, Monkey.like_posts.where(target: post).count
    post.reload
    assert_equal 2, post.likes_count

    a2 = Monkey.create_action('star', target: post, user: user1)
    assert_equal false, a2.new_record?
    assert_not_equal a.id, a2.id
    assert_not_equal a1.id, a2.id
    assert_equal 1, Monkey.star_posts.where(target: post).count
    post.reload
    assert_equal 1, post.stars_count

    a3 = Monkey.create_action('follow', target: post, user: user1)
    assert_equal false, a3.new_record?
    assert_not_equal a.id, a3.id
    assert_not_equal a1.id, a3.id
    assert_not_equal a2.id, a3.id
    assert_equal 1, Monkey.follow_posts.where(target: post).count
  end

  test ".destroy_action" do
    u1 = create(:user)
    u2 = create(:user)
    u3 = create(:user)
    u4 = create(:user)

    # all user -> follow u2
    action = Monkey.create_action('follow', target: u2, user: u1)
    assert_not_nil(action)
    Monkey.create_action('follow', target: u2, user: u3)
    Monkey.create_action('follow', target: u2, user: u4)
    assert_equal(3, u2.reload.followers_count)
    assert_equal(1, u1.reload.following_count)
    assert_equal(1, u3.reload.following_count)
    assert_equal(1, u4.reload.following_count)
    Monkey.destroy_action('follow', target: u2, user: u3)
    Monkey.destroy_action('follow', target: u2, user: u4)
    assert_equal(1, u2.reload.followers_count)
    assert_equal(0, u3.reload.following_count)
    assert_equal(0, u4.reload.following_count)

    # u2 -> follow -> u1
    action = Monkey.create_action('follow', target: u1, user: u2)
    assert_not_nil(action)
    assert_equal(1, u2.reload.following_count)
    assert_equal(1, u1.reload.followers_count)
  end

  test ".destroy_action with not found work" do
    assert_equal false, Monkey.destroy_action('follow', target_type: 'Post', post_id: -1, user: create(:user))
  end

  test ".find_action" do
    user = create(:user)
    post = create(:post)
    action = Monkey.create_action('like', target: post, user: user)
    result = Monkey.find_action('like', target: post, user: user)
    assert_equal action.id, result.id
    result = Monkey.find_action('like', target_type: 'Post', target_id: post.id, user: user)
    assert_equal action.id, result.id
  end
end
