/*
 * This file is part of budgie-desktop
 * 
 * Copyright © 2015-2017 Ikey Doherty <ikey@solus-project.com>
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

namespace Budgie {

/**
 * AppletSettingsFrame provides a UI wrapper for Applet Settings
 */
public class AppletSettingsFrame : Gtk.Box
{
    public AppletSettingsFrame()
    {
        Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        Gtk.Label lab = new Gtk.Label(_("Configure applet"));
        lab.set_use_markup(true);
        lab.halign = Gtk.Align.START;
        lab.margin_bottom = 6;
        valign = Gtk.Align.START;

        this.get_style_context().add_class("settings-frame");
        lab.get_style_context().add_class("settings-title");

        var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        sep.margin_bottom = 6;
        this.pack_start(lab, false, false, 0);
        this.pack_start(sep, false, false, 0);
    }

    public override void add(Gtk.Widget widget)
    {
        this.pack_start(widget, false, false, 0);
    }
}

/**
 * AppletItem is used to represent a Budgie Applet in the list
 */
public class AppletItem : Gtk.Box {

    /**
     * We're bound to the info
     */
    public unowned Budgie.AppletInfo? applet { public get ; construct set; }

    private Gtk.Image image;
    private Gtk.Label label;

    /**
     * Construct a new AppletItem for the given applet
     */
    public AppletItem(Budgie.AppletInfo? info)
    {
        Object(applet: info);

        get_style_context().add_class("applet-item");

        margin_top = 4;
        margin_bottom = 4;

        image = new Gtk.Image();
        image.margin_start = 12;
        image.margin_end = 14;
        pack_start(image, false, false, 0);

        label = new Gtk.Label("");
        label.margin_end = 18;
        label.halign = Gtk.Align.START;
        pack_start(label, false, false, 0);

        this.applet.bind_property("description", this.label, "label", BindingFlags.DEFAULT|BindingFlags.SYNC_CREATE);
        this.applet.bind_property("icon", this.image, "icon-name", BindingFlags.DEFAULT|BindingFlags.SYNC_CREATE);
        this.image.icon_size = Gtk.IconSize.MENU;

        this.show_all();
    }
}

/**
 * AppletsPage contains the applets view for a given panel
 */
public class AppletsPage : Gtk.Box {

    unowned Budgie.Toplevel? toplevel;
    unowned Budgie.DesktopManager? manager = null;

    /* Used applet storage */
    Gtk.ListBox listbox_applets;
    HashTable<string,AppletItem?> items;

    /* Allow us to display settings when each item is selected */
    Gtk.Stack settings_stack;

    public AppletsPage(Budgie.DesktopManager? manager, Budgie.Toplevel? toplevel)
    {
        Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);
        this.manager = manager;
        this.toplevel = toplevel;

        margin = 6;

        this.configure_list();
        this.configure_actions();

        /* Insert them now */
        foreach (var applet in this.toplevel.get_applets()) {
            this.applet_added(applet);
        }

        Idle.add(()=> {
            this.settings_stack.set_visible_child_name("main");
            return false;
        });

        toplevel.applet_added.connect(this.applet_added);
        toplevel.applet_removed.connect(this.applet_removed);
    }

    /**
     * Configure the main display list used to show the currently used
     * applets for the panel
     */
    void configure_list()
    {
        items = new HashTable<string,AppletItem?>(str_hash, str_equal);

        var frame_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

        /* Allow moving the applet */
        var move_box = new Gtk.ButtonBox(Gtk.Orientation.HORIZONTAL);
        move_box.set_layout(Gtk.ButtonBoxStyle.START);
        move_box.get_style_context().add_class("linked");
        var move_up_button = new Gtk.Button.from_icon_name("go-up-symbolic", Gtk.IconSize.MENU);
        var move_down_button = new Gtk.Button.from_icon_name("go-down-symbolic", Gtk.IconSize.MENU);
        move_box.add(move_up_button);
        move_box.add(move_down_button);

        var button_remove_applet = new Gtk.Button.from_icon_name("edit-delete-symbolic", Gtk.IconSize.MENU);
        move_box.add(button_remove_applet);

        frame_box.pack_start(move_box, false, false, 0);
        var frame = new Gtk.Frame(null);
        frame.margin_end = 20;
        frame.margin_top = 12;
        frame.add(frame_box);

        listbox_applets = new Gtk.ListBox();
        listbox_applets.set_activate_on_single_click(true);
        listbox_applets.row_selected.connect(row_selected);
        frame_box.pack_start(listbox_applets, true, true, 0);
        this.pack_start(frame, true, true, 0);

        /* Make sure we can sort + header */
        listbox_applets.set_sort_func(this.do_sort);
        listbox_applets.set_header_func(this.do_headers);
    }

    /**
     * Configure the action grid to manipulation the applets
     */
    void configure_actions()
    {
        var grid = new SettingsGrid();
        grid.small_mode = true;
        this.pack_start(grid, false, false, 0);

        /* Allow adding new applets*/
        var button_add = new Gtk.Button.from_icon_name("list-add-symbolic", Gtk.IconSize.MENU);
        button_add.valign = Gtk.Align.CENTER;
        button_add.vexpand = false;
        button_add.get_style_context().add_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        button_add.get_style_context().add_class("round-button");
        grid.add_row(new SettingsRow(button_add,
            _("Add applet"),
            _("Choose a new applet to add to this panel")));

        settings_stack = new Gtk.Stack();
        settings_stack.halign = Gtk.Align.START;
        settings_stack.valign = Gtk.Align.START;
        settings_stack.margin_top = 24;
        grid.attach(settings_stack, 0, ++grid.current_row, 2, 1);


        /* Placeholder for no settings */
        var placeholder = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        placeholder.margin_top = 24;
        placeholder.valign = Gtk.Align.START;
        var placeholder_img = new Gtk.Image.from_icon_name("dialog-info-symbolic", Gtk.IconSize.MENU);
        var placeholder_text = new Gtk.Label(_("No settings available"));
        placeholder_text.set_margin_start(14);
        placeholder.pack_start(placeholder_img, false, false, 0);
        placeholder.pack_start(placeholder_text, false, false, 0);
        placeholder.show_all();
        settings_stack.add_named(placeholder, "no-settings");

        /* Empty placeholder for no selection .. */
        var empty = new Gtk.EventBox();
        settings_stack.add_named(empty, "main");
    }

    /**
     * Changed the row so update the UI
     */
    private void row_selected(Gtk.ListBoxRow? row)
    {
        if (row == null) {
            this.settings_stack.set_visible_child_name("main");
            return;
        }
        unowned AppletItem? item = row.get_child() as AppletItem;
        unowned Gtk.Widget? lookup = this.settings_stack.get_child_by_name(item.applet.uuid);
        if (lookup == null) {
            this.settings_stack.set_visible_child_name("no-settings");
            return;
        }
        this.settings_stack.set_visible_child(lookup);
    }

    /**
     * We have a new applet, so stored it in the list
     */
    private void applet_added(Budgie.AppletInfo? applet)
    {
        if (this.items.contains(applet.uuid)) {
            return;
        }

        /* Allow viewing settings on demand */
        if (applet.applet.supports_settings()) {
            var frame = new AppletSettingsFrame();
            frame.add(applet.applet.get_settings_ui());
            settings_stack.add_named(frame, applet.uuid);
        }

        /* Stuff the new item into display */
        var item = new AppletItem(applet);
        listbox_applets.add(item);
        items[applet.uuid] = item;
    }

    /**
     * An applet was removed, so remove from our list also
     */
    private void applet_removed(string uuid)
    {
        AppletItem? item = items.lookup(uuid);
        Gtk.Widget? lookup = null;

        if (item == null) {
            return;
        }

        /* Remove the child again */
        lookup = settings_stack.get_child_by_name(uuid);
        if (lookup != null) {
            lookup.destroy();
        }

        item.get_parent().destroy();
        items.remove(uuid);
    }

    /**
     * Convert a string alignment into one that is sortable
     */
    int align_to_int(string al)
    {
        switch (al) {
            case "start":
                return 0;
            case "center":
                return 1;
            case "end":
            default:
                return 2;
        }
    }

    /**
     * Sort the list in accordance with alignment and actual position
     */
    int do_sort(Gtk.ListBoxRow? before, Gtk.ListBoxRow? after)
    {
        unowned Budgie.AppletInfo? before_info = (before.get_child() as AppletItem).applet;
        unowned Budgie.AppletInfo? after_info = (after.get_child() as AppletItem).applet;

        if (before_info != null && after_info != null && before_info.alignment != after_info.alignment) {
            int bi = align_to_int(before_info.alignment);
            int ai = align_to_int(after_info.alignment);

            if (ai > bi) {
                return -1;
            } else {
                return 1;
            }
        }

        if (after_info == null) {
            return 0;
        }

        if (before_info.position < after_info.position) {
            return -1;
        } else if (before_info.position > after_info.position) {
            return 1;
        }

        return 0;
    }

    /**
     * Provide headers in the list to separate the visual positions
     */
    void do_headers(Gtk.ListBoxRow? before, Gtk.ListBoxRow? after)
    {
        Gtk.Widget? child = null;
        string? prev = null;
        string? next = null;
        unowned Budgie.AppletInfo? before_info = null;
        unowned Budgie.AppletInfo? after_info = null;

        if (before != null) {
            before_info = (before.get_child() as AppletItem).applet;
            prev = before_info.alignment;
        }

        if (after != null) {
            after_info = (after.get_child() as AppletItem).applet;
            next = after_info.alignment;
        }

        if (after == null || prev != next) {
            Gtk.Label? label = null;
            switch (prev) {
                case "start":
                    label = new Gtk.Label(_("Start"));
                    break;
                case "center":
                    label = new Gtk.Label(_("Center"));
                    break;
                default:
                    label = new Gtk.Label(_("End"));
                    break;
            }
            label.get_style_context().add_class("dim-label");
            label.get_style_context().add_class("applet-row-header");
            label.halign = Gtk.Align.START;
            label.margin_start = 4;
            label.margin_top = 2;
            label.margin_bottom = 2;
            label.valign = Gtk.Align.CENTER;
            label.use_markup = true;
            before.set_header(label);
        } else {
            before.set_header(null);
        }
    }

} /* End class */

} /* End namespace */
