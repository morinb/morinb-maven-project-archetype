#! /bin/bash
# 1/ create release branch
DIR=$1

if [ -d "$DIR" ]
then
	cd $DIR
else 
	echo "$DIR is not a valid directory"
	exit 3
fi

DEVELOP_BRANCH=$(git config gitflow.branch.develop)
MASTER_BRANCH=$(git config gitflow.branch.master)

nextReleaseVersion=
nextSnapshotVersion=

currentPomVersion=$(mvn org.apache.maven.plugins:maven-help-plugin:evaluate -Dexpression=project.version | sed -n -e '/^\[.*\]/ !{ /^[0-9]/ {p; q } }')
guessedCurrentVersion=${currentPomVersion//-SNAPSHOT}

set -e

if [ -z ${nextReleaseVersion} ]
then
	echo -n "Please specifify next release version [${guessedCurrentVersion}]: "
	read nextReleaseVersion
fi

if [ -z ${nextReleaseVersion} ]
then
	nextReleaseVersion=${guessedCurrentVersion}
fi

git flow release start ${nextReleaseVersion}

# 2/ check branch is clean

if [ -n "$(git status --porcelain)" ]
then
	echo -n "Branch is not clean, please commit or stash tour changes !"
	exit 1
fi

# 3/ upgrade pom version

mvn versions:set -DnewVersion=${nextReleaseVersion}

# 4/ test version

mvn test verify

if [ $? -ne 0 ] 
then
	echo -n "Tests have failed. Stopping !"
	exit 2
fi

# 5/ validate pom

mvn versions:commit

git add pom.xml
git commit -m "[Release] Update pom version to ${nextReleaseVersion}"

# 6/ finish release

git flow release finish ${nextReleaseVersion}

# 7/ Upgrade pom for next snapshot
mvn release:update-versions -DautoVersionSubmodules=true
git add pom.xml
git commit -m "[Release] Update pom for next version"

#8 / Cleaning
mvn clean

git co ${MASTER_BRANCH} && git push && git co ${DEVELOP_BRANCH} && git push && git push --tags
