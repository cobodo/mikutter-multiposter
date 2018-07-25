# -*- coding: utf-8 -*-

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

    # 同じpriority（両方ともデフォルト）ならPlugin.callの順序は保たれると仮定している
    Plugin.call(:world_change_current, world)
    Plugin.call(:compose_by_specific_world2, i_postbox, current)
  end

  on_compose_by_specific_world2 do |i_postbox, current|
    i_postbox.post_it!
    Plugin.call(:world_change_current, current)
  end
end
