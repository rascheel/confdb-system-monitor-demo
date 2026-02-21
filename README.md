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

> [!TIP]
> Make sure you have a key registered with the Store: `snapcraft register-key <key-name>`

> [!TIP]
> To get the `key-sha-digest`, run `snap keys` and pick it from the `SHA3-384` column.

Finally, `ack` the confdb-schema assertion itself.


