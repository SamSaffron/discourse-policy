# frozen_string_literal: true

require 'rails_helper'

describe DiscoursePolicy::CheckPolicy do

  before do
    Jobs.run_immediately!
  end

  fab!(:user1) do
    Fabricate(:user)
  end

  fab!(:user2) do
    Fabricate(:user)
  end

  fab!(:group) do
    group = Fabricate(:group)
    group.add(user1)
    group.add(user2)
    group
  end

  def accept_policy(post)
    [user1, user2].each do |u|
      PolicyUser.add!(u, post.post_policy)
    end
  end

  it "correctly renews policise with no renew-start" do
    freeze_time Time.utc(2019)

    raw = <<~MD
     [policy group=#{group.name} renew=400]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))

    freeze_time Time.utc(2021)
    accept_policy(post)

    freeze_time Time.utc(2022)
    DiscoursePolicy::CheckPolicy.new.execute

    post.reload
    expect(post.post_policy.accepted_by.sort).to eq([user1, user2])

    freeze_time Time.utc(2023)
    DiscoursePolicy::CheckPolicy.new.execute

    post.reload
    expect(post.post_policy.accepted_by).to eq([])
  end

  it "expires only for user with expired policy" do
    freeze_time Time.utc(2019)

    raw = <<~MD
     [policy group=#{group.name} renew=364]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))

    freeze_time Time.utc(2021)
    accept_policy(post)

    freeze_time Time.utc(2022)
    PolicyUser.where(user_id: user2.id).update(accepted_at: Time.now)
    DiscoursePolicy::CheckPolicy.new.execute

    post.reload
    expect(post.post_policy.accepted_by.sort).to eq([user2])
  end

  it "expires just for expired policy" do
    freeze_time Time.utc(2019)

    raw = <<~MD
     [policy group=#{group.name} renew=364]
     I always open **doors**!
     [/policy]
    MD

    raw2 = <<~MD
     [policy group=#{group.name} renew=1000]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))
    post2 = create_post(raw: raw2, user: Fabricate(:admin))

    freeze_time Time.utc(2021)
    accept_policy(post)
    accept_policy(post2)

    freeze_time Time.utc(2022)
    DiscoursePolicy::CheckPolicy.new.execute

    post.reload
    expect(post.post_policy.accepted_by.sort).to eq([])
    expect(post2.post_policy.accepted_by.sort).to eq([user1, user2])
  end

  it "correctly renews policies" do

    freeze_time Time.utc(2019)

    raw = <<~MD
     [policy group=#{group.name} renew=100 renew-start="17-10-2020"]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))

    accept_policy(post)

    freeze_time Time.utc(2020)
    DiscoursePolicy::CheckPolicy.new.execute

    post.reload
    # did not hit renew start
    expect(post.post_policy.accepted_by.sort).to eq([user1, user2])

    freeze_time Time.utc(2020, 10, 18)

    DiscoursePolicy::CheckPolicy.new.execute

    post.reload
    expect(post.post_policy.accepted_by.sort).to eq([])

    accept_policy(post)

    freeze_time (Time.utc(2020, 10, 17) + 101.days)

    DiscoursePolicy::CheckPolicy.new.execute

    post.reload
    expect(post.post_policy.accepted_by.sort).to eq([])
  end

  it "will correctly notify users" do
    SiteSetting.queue_jobs = false
    freeze_time

    raw = <<~MD
     [policy group=#{group.name} reminder=weekly]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))

    DiscoursePolicy::CheckPolicy.new.execute

    expect(user1.notifications.where(notification_type: Notification.types[:topic_reminder]).count).to eq(0)
    expect(user2.notifications.where(notification_type: Notification.types[:topic_reminder]).count).to eq(0)

    freeze_time 2.weeks.from_now

    DiscoursePolicy::CheckPolicy.new.execute
    DiscoursePolicy::CheckPolicy.new.execute

    expect(user1.notifications.where(notification_type: Notification.types[:topic_reminder], topic_id: post.topic_id, post_number: 1).count).to eq(1)
    expect(user2.notifications.where(notification_type: Notification.types[:topic_reminder], topic_id: post.topic_id, post_number: 1).count).to eq(1)
  end
end
