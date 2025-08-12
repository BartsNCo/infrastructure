source .env
if [ -d unity-project ]; then
    rm -rf unity-project
fi
git clone --depth 1 -b dev "https://${GITHUB_TOKEN}@github.com/BartsNCo/Unity.git" unity-project
rm -rf unity-project/.git

cp -r /home/ubuntu/images/ToursAssets /home/ubuntu/unity-project/BartsViewerBundlesBuilder/Assets/

UNITY_EDITOR_PATH="/home/ubuntu/Unity/Hub/Editor/6000.0.55f1/Editor/Unity"

"$UNITY_EDITOR_PATH" \
	-batchmode \
	-quit \
	-nographics \
	-silent-crashes \
	-logFile /dev/stdout \
	-projectPath unity-project/BartsViewerBundlesBuilder \
	-buildTarget android


