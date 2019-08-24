# GitHub Action for Git Push

The GitHub Actions for pushing to Git repository local changes authorizing using GitHub token.


## Usage

### Example Workflow file

An example workflow to authenticate with Google Cloud Platform:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
...
    - run: |
        ...
    - uses: ad-m/git-push-action@master
      with:
        repo-token: ${{ secrets.GITHUB_TOKEN }}
```

Subsequent actions in the workflow will then be able to use `gcloud` as that user ([see `cli` for examples](/cli)).

### Secrets

* `GCLOUD_AUTH` **Required** Base64 encoded service account key exported as JSON
   - For information about service account keys please see the [Google Cloud docs](https://cloud.google.com/sdk/docs/authorizing)
   - For information about using Secrets in Actions please see the [Actions docs](https://developer.github.com/actions/creating-workflows/storing-secrets/).

Example on encoding from a terminal : `base64 ~/<account_id>.json`

## License

The Dockerfile and associated scripts and documentation in this project are released under the [MIT License](LICENSE).

Container images built with this project include third party materials. See [THIRD_PARTY_NOTICE.md](THIRD_PARTY_NOTICE.md) for details.
