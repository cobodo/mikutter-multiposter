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
end
