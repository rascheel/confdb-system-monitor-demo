# Disclaimer
Vibe coded slop

# Pre-reqs
## Enable confdb
>sudo snap set system experimental.confdb=true

## Register pre-req asserts
This is necessary for "ack"ing the confdb schema assertion

**cannot resolve prerequisite assertion**

This error occurs when trying to acknowledge the assertion but some requisite assertions are not found locally. We'll need to fetch them from the Store.

To fetch and acknowledge your `account` assertion, run:

```console
$ snap known --remote account account-id=<your-account-id> > /tmp/account.assert
$ sudo snap ack /tmp/account.assert
```

To fetch and acknowledge the `account-key` assertion, run:

```console
$ snap known --remote account-key public-key-sha3-384=<key-sha-digest> > /tmp/account-key.assert
$ sudo snap ack /tmp/account-key.assert
```

# Build/install/configure
## Generate and sign the assertions for the confdb schemas
NOTE: the recommended way to store a schema is as a yaml file, then convert it to .json, then sign it. This is due to the pain of escaping the schema in the .json file

Confdb schemas need your account id and some other stuff in them that is annoying to tweak every time. The below script handles all that nuance for you.

> [!TIP]
> Make sure you have changed the KEY_NAME variable in the gen_and_load_confdb_assert.sh script to match your snapcraft key from the prereqs

```console
$ ./gen_and_load_confdb_assert.sh cpu-schema
$ ./gen_and_load_confdb_assert.sh fault-mgr-schema
```

> [!TIP]
> If you ever change one of the schema files you *must* increment the revision number or the change will silently be ignored

## Build the snaps and install
When using confdb you need to insert your account ID into several places and these scripts handle that all for you plus connecting the connectors
```console
$ ./build_and_install_snap.sh cpu-monitor
$ ./build_and_install_snap.sh fault-monitor
```

## Configure the faults config
Run the below script to set the config for the faults. Can tweak it as desired in the script and the observe-view-* hooks in fault-monitor should notice the config change and take effect immediately.
```console
$ ./configure_fault_config.sh
```

# Monitor
You can take a look at the output by watching the snap logs for the fault-monitor: `snap logs -f fault-monitor`

You can also just directly request data fields from the load-view-* confdb hooks: `sudo snap get <YOUR_ACCOUNT_ID>/cpu-stats/monitor data`

