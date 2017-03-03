EAPI=5

PYTHON_REQ_USE="gdbm,sqlite"
PYTHON_COMPAT=( python{2_6,2_7} )

inherit python-r1 user

DESCRIPTION="Apache Bloodhound is an open source web-based project management and bug tracking system."
HOMEPAGE="http://bloodhound.apache.org/"
LICENSE=""
SRC_URI="http://mirror.catn.com/pub/apache/bloodhound/apache-bloodhound-${PV}.tar.gz"
RESTRICT="mirror"
SLOT="0"
KEYWORDS="~x86 ~amd64"
IUSE=""

RDEPEND="${PYTHON_DEPS}
        dev-python/virtualenv
        dev-python/python-ldap"

DEPEND="${DEPEND}"

TARGET_DIR=/opt/apache-bloodhound

pkg_setup() {
	enewgroup bloodhound
	enewuser bloodhound -1 /bin/bash /var/lib/bloodhound bloodhound
}

src_unpack() {
	unpack ${A}
}

src_prepare() {
	S="${WORKDIR}/build"
	mkdir -p "${S}"
}

src_install() {
	keepdir "/var/lib/bloodhound"

	exeinto "/var/lib/bloodhound"
	doexe "${FILESDIR}/.bashrc"

	insinto "${TARGET_DIR}"
	doins -r "${WORKDIR}/apache-bloodhound-${PV}/"*

	newinitd "${FILESDIR}/init.sh" bloodhound
	newconfd "${FILESDIR}/conf" bloodhound
}

pkg_postinst() {
	pushd "${TARGET_DIR}/installer"
	virtualenv /var/lib/bloodhound/bhenv --python=python2.7
	source /var/lib/bloodhound/bhenv/bin/activate
	pip install -r requirements.txt
	python bloodhound_setup.py --environments_directory=/var/lib/bloodhound/bloodhound-environments --default-product-prefix=DEF --database-type=sqlite --admin-user=admin --admin-password=admin
	popd

	chown -R bloodhound:bloodhound "/var/lib/bloodhound"
#	exit 1

}
