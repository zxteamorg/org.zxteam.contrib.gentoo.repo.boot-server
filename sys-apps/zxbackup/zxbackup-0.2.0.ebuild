EAPI=2

DESCRIPTION=""
HOMEPAGE="http://project.zxteam.net/unix-tools/zxbackup/"
LICENSE="GPL2"
SRC_URI=""
RESTRICT="mirror"
SLOT="0"
KEYWORDS="~x86 ~amd64 ~arm"
IUSE=""

DEPEND="sys-fs/lvm2"
RDEPEND="${DEPEND}"

src_install() {
    newinitd "${FILESDIR}/${PV}/snap.init" zxbackup-snap
    newconfd "${FILESDIR}/${PV}/snap.conf" zxbackup-snap
    newsbin "${FILESDIR}/${PV}/zxbackup" zxbackup
    dosym "/usr/sbin/zxbackup" "/usr/sbin/zxbackup-create-local-snapshot"
    dosym "/usr/sbin/zxbackup" "/usr/sbin/zxbackup-create-remote-snapshot"
    dosym "/usr/sbin/zxbackup" "/usr/sbin/zxbackup-download-remote-snapshots"
    dosym "/usr/sbin/zxbackup" "/usr/sbin/zxbackup-update-delta"
}
