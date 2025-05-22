using Reactive, GTK, GtkReactive, Observables

abstract type UIComponent end

struct ReactiveButton <: UIComponent
    widget::GtkButton
    on_click::Observable{Function}
end

struct ReactiveLabel <: UIComponent
    widget::GtkLabel
    text::Observable{String}
end

struct ReactiveTextInput <: UIComponent
    widget::GtkEntry
    text::Observable{String}
end

struct ReactiveContainer <: UIComponent
    widget::GtkBox
    children::Vector{UIComponent}
end

function create_button(label::String; on_click=Observable(() -> nothing))
    btn = GtkButton(label)
    return ReactiveButton(btn, on_click)
end

function create_label(initial_text::String="")
    lbl = GtkLabel(initial_text)
    txt = Observable(initial_text)
    return ReactiveLabel(lbl, txt)
end

function create_text_input(initial_text::String="")
    entry = GtkEntry()
    txt = Observable(initial_text)
    Gtk.set_gtk_property!(entry, :text, initial_text)
    return ReactiveTextInput(entry, txt)
end

function create_container(orientation::GtkOrientation=GtkOrientation.VERTICAL)
    box = GtkBox(orientation)
    return ReactiveContainer(box, [])
end

function add_child!(container::ReactiveContainer, child::UIComponent)
    push!(container.children, child)
    push!(container.widget, child.widget)
    return container
end

function bind_label_to_text!(label::ReactiveLabel)
    on_any(label.text) do new_text
        Gtk.set_gtk_property!(label.widget, :label, new_text)
    end
end

function bind_text_input!(input::ReactiveTextInput)
    connect!(input.widget, "changed") do widget
        text = Gtk.get_gtk_property(widget, :text, String)
        send!(input.text, text)
    end
    on_any(input.text) do new_text
        current_text = Gtk.get_gtk_property(input.widget, :text, String)
        if current_text != new_text
            Gtk.set_gtk_property!(input.widget, :text, new_text)
        end
    end
end

function bind_button_click!(button::ReactiveButton)
    connect!(button.widget, "clicked") do _
        func = get!(button.on_click)
        func()
    end
end

function reactive_ui()
    main_box = create_container(GtkOrientation.VERTICAL)
    label = create_label("Enter your name:")
    input = create_text_input()
    greeting_label = create_label("")
    button = create_button("Greet")
    add_child!(main_box, label)
    add_child!(main_box, input)
    add_child!(main_box, button)
    add_child!(main_box, greeting_label)

    bind_label_to_text!(label)
    bind_text_input!(input)

    on_any(input.text) do txt
        greeting = "Hello, " * txt
        send!(greeting_label.text, greeting)
    end

    bind_button_click!(button)
    on_button_click = button.on_click
    push!(on_button_click) do _
        current_greeting = Gtk.get_gtk_property(greeting_label.widget, :label, String)
        println("Button clicked! Greeting: $current_greeting")
    end

    return main_box
end

function start_app()
    win = GtkWindow("Reactive UI") 
    ui = reactive_ui()
    push!(ui.children, ui) 
    set_window_properties!(win)
    push!(win, ui.widget)
    showall(win)
    Gtk.GtkMain()
end

function set_window_properties!(win::GtkWindow)
    Gtk.set_gtk_property!(win, :default_height, 300)
    Gtk.set_gtk_property!(win, :default_width, 400)
end

function main()
    start_app()
end

main()