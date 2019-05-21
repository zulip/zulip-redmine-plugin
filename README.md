# Redmine Zulip Plugin

Get Zulip notifications for your Redmine issues!

## Installing

0. Please navigate to your Redmine instance's root directory by running:

```sh
cd /path/to/redmine
```

1. Clone the **Redmine Zulip Plugin** into `plugins` directory

```sh
git clone https://github.com/zulip/zulip-redmine-plugin.git plugins/redmine_zulip
```

2. **Restart** your Redmine instance

3. Update the Redmine database by running:

```sh
rake redmine:plugins:migrate
```

## Configuring plugin settings

#### Global settings

Log into your Redmine instance, click on **Administration** in the top-left corner, then click on **Plugins**.

Find the **Redmine Zulip** plugin, and click **Configure**. You must now set the following:

* Zulip URL (e.g `https://yourZulipDomain.zulipchat.com/`)
* Zulip Bot E-mail
* Zulip Bot API key


#### Project settings

Go to your project's **Settings** page, and select the **Zulip** tab. Now, you may:

* Specify the Zulip stream
* Enable/disable private notifications on tasks assignments
* Enable/disable notifications on issues update
* Enable/disable notifications on milestone progress
