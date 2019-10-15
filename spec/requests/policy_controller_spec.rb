# frozen_string_literal: true

require "rails_helper"

describe DiscoursePolicy::PolicyController do
  before do
    SiteSetting.queue_jobs = false
  end

  it 'can not apply a policy to groups that are too big' do

    group = Fabricate(:group)
    user1 = Fabricate(:user)
    user2 = Fabricate(:user)

    group.add(user1)
    group.add(user2)

    sign_in(user1)

    raw = <<~MD
     [policy group=#{group.name}]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:moderator))

    SiteSetting.policy_max_group_size = 1

    put "/policy/accept.json", params: { post_id: post.id }

    expect(response.status).not_to eq(200)
    expect(response.body).to include('too large')
  end

  it 'can allows users to accept/reject policy' do

    group = Fabricate(:group)
    user1 = Fabricate(:user)
    user2 = Fabricate(:user)

    group.add(user1)
    group.add(user2)

    sign_in(user1)

    raw = <<~MD
     [policy group=#{group.name}]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:moderator))

    put "/policy/accept.json", params: { post_id: post.id }

    expect(response.status).to eq(200)
    post.reload

    expect(post.post_policy.accepted_by.map(&:id)).to eq([user1.id])

    sign_in(user2)
    put "/policy/accept.json", params: { post_id: post.id }

    expect(response.status).to eq(200)
    post.reload

    expect(post.post_policy.accepted_by.map(&:id).sort).to eq([user1.id, user2.id])

    put "/policy/unaccept.json", params: { post_id: post.id }
    expect(response.status).to eq(200)

    post = Post.find(post.id)

    expect(post.post_policy.accepted_by.map(&:id)).to eq([user1.id])
  end
end
