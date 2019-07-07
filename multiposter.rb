# -*- coding: utf-8 -*-

class Gtk::PostBox < Gtk::EventBox
  def post_it(world: target_world)
    if postable?
      return unless before_post(world: world || target_world)
      @posting = Plugin[:gtk].compose(
        world || target_world,
        to_display_only? ? nil : @to.first,
        **compose_options
      ).next{
        Plugin.call(:gui_postbox_posted, self)
        destroy
      }.trap{ |err|
        warn err
        end_post
      }
      start_post
    end
  end
end

Plugin.create(:multiposter) do
  command(
    :multipost,
    name: 'マルチポストする',
    condition: -> (opt) { opt.widget.editable? },
    visible: true,
    icon: Skin['post.png'],
    role: :postbox
  ) do |opt|
    worlds = Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.to_a
    i_postbox = opt.widget
    postbox, = Plugin.filtering(:gui_get_gtk_widget, i_postbox)
    body = postbox.widget_post.buffer.text

    dialog "マルチポスト" do
      self[:body] = body
      label "投稿先にチェックを入れてOKを押すと投稿します"
      worlds.each_index do |i|
        name = worlds[i].title
        key = :"world#{i}"
        boolean name, key
      end
      multitext "本文", :body
    end.next do |result|
      body = result[:body]
      worlds.each_index do |i|
        if result[:"world#{i}"]
          compose worlds[i], body: body
        end
      end

      if Gtk::PostBox.list[0] != postbox
        postbox.destroy
      else
        postbox.widget_post.buffer.text = ''
      end
    end
  end

  def post_to_worlds(opt, worlds)
    i_postbox = opt.widget
    postbox, = Plugin.filtering(:gui_get_gtk_widget, i_postbox)
    body = postbox.widget_post.buffer.text
    return if (body.nil? || body.empty?)

    ds = []
    worlds.each do |world|
      ds << compose(world, body: body)
    end
    Delayer::Deferred.when(ds).next {
      if Gtk::PostBox.list[0] != postbox
        postbox.destroy
      else
        postbox.widget_post.buffer.text = ''
      end
    }
  end

  command(
    :multipost_portal,
    name: 'マルチポストする(Portal)',
    condition: -> (opt) {
      opt.widget.editable? && Plugin.filtering(:world_current, nil).first.class.slug == :portal
    },
    visible: true,
    icon: Skin['post.png'],
    role: :postbox
  ) do |opt|
    portal = Plugin.filtering(:world_current, nil).first
    worlds = [portal.world, portal.next_portal.world]

    post_to_worlds(opt, worlds)
  end

  command(
    :post_to_secondary_world,
    name: 'Secondary Worldにポストする(Portal)',
    condition: -> (opt) {
      opt.widget.editable? && Plugin.filtering(:world_current, nil).first.class.slug == :portal
    },
    visible: true,
    icon: Skin['post.png'],
    role: :postbox
  ) do |opt|
    portal = Plugin.filtering(:world_current, nil).first
    post_to_worlds(opt, [portal.next_portal.world])
  end

  filter_command do |menu|
    Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.each do |world|
      slug = "compose_by_#{world.slug}".to_sym
      menu[slug] = {
        slug: slug,
        exec: -> opt {
          Plugin.call(:compose_by_specific_world, opt.widget, world)
        },
        plugin: @name,
        name: _('%{title}(%{world}) で投稿する'.freeze) % {
          title: world.title,
          world: world.class.slug
        },
        condition: -> opt { opt.widget.editable?  },
        visible: false,
        role: :postbox,
        icon: world.icon } end
    [menu]
  end

  on_compose_by_specific_world do |i_postbox, world|
    current = Plugin.filtering(:world_current, nil).first
    next unless current

    # 次にworldが変更されたタイミングでpost_itをトリガーするイベントハンドラ
    change_observer = on_primary_service_changed do |cur|
      # world変更を検知できたのでもう必要ない
      detach change_observer

      # 投稿後にworldを戻すイベントハンドラ
      posted_observer = on_gui_postbox_posted do |_|
        detach posted_observer
        Plugin.call(:world_change_current, current)
      end
      # 投稿を実行
      Plugin.call(:gui_postbox_post, i_postbox)
    end
    # worldを変更して↑を起動する
    Plugin.call(:world_change_current, world)
  end
end
