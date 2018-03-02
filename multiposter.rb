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
    end
  end
end
