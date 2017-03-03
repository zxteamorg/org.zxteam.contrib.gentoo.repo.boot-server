DESCRIPTION=""
HOMEPAGE="http://www.zxteam.net/"
LICENSE="GPL2"
SRC_URI=""
RESTRICT="mirror"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE=""

DEPEND=""
RDEPEND="${DEPEND}"

src_install() {

    newinitd "${FILESDIR}/init.sh" virtualbox
    newconfd "${FILESDIR}/conf" virtualbox.example
}
