EAPI=2
DESCRIPTION="imagemount: This tool mount disk images as loop device, initialize logical volumes and mount"
HOMEPAGE="http://projects.zxteam.net/unix-tools/imagemount/"
LICENSE="GPL2"
SRC_URI=""
RESTRICT="mirror"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE=""

DEPEND="sys-fs/lvm2"
RDEPEND="${DEPEND}"

src_install() {
    newinitd "${FILESDIR}/${PV}/init.sh" imagemount
    newconfd "${FILESDIR}/${PV}/conf" imagemount
    newconfd "${FILESDIR}/${PV}/conf.instance1" imagemount.instance1
}
