# ZXTeam's Gentoo Portage Repository

## Add the repository to your system
###### Make configuration file _**/etc/portage/repos.conf/zxteam.conf**_ with following content
```
[zxteam]
location = /usr/local/portage/zxteam
sync-type = git
sync-uri =https://github.com/zxteamorg/org.zxteam.gentoo-repo.git
auto-sync = yes
```
###### Sync the repository
```bash
# emerge --sync zxteam
```
## Select desired system profile
```bash
# eselect profile list
...

...
# eselect profile set 12
```
