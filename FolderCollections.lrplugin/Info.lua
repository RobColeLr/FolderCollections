--[[
        Info.lua
--]]

return {
    appName = "Folder Collections",
    author = "Rob Cole",
    authorsWebsite = "www.robcole.com",
    donateUrl = "http://www.robcole.com/Rob/Donate",
    platforms = { 'Windows', 'Mac' },
    pluginId = "com.robcole.lightroom.FolderCollections",
    xmlRpcUrl = "http://www.robcole.com/Rob/_common/cfpages/XmlRpc.cfm",
    LrPluginName = "rc Folder Collections",
    LrSdkMinimumVersion = 3.0,
    LrSdkVersion = 5.0,
    LrPluginInfoUrl = "http://www.robcole.com/Rob/ProductsAndServices/FolderCollectionsLrPlugin",
    LrPluginInfoProvider = "ExtendedManager.lua",
    LrToolkitIdentifier = "com.robcole.lightroom.FolderCollections",
    LrInitPlugin = "Init.lua",
    LrShutdownPlugin = "Shutdown.lua",
    --LrMetadataProvider = "Metadata.lua",
    LrMetadataTagsetFactory = "Tagsets.lua", -- this required still for Lr3 compatibility. After Lr5 is released, I can start using LrForceInitPlugin (or for plugins that are lr4-only).
    LrExportMenuItems = {
        --{
        --    title = "&Re-build Folder Collections",
        --    file = "mBuildFolderCollections.lua",
        --},
        {
            title = "&Sync Selected Sources",
            file = "mSyncSelected.lua",
        },
        {
            title = "&Go To Folders", -- not sure if I need this, although it does multiple sources, native LR's does not ###2
            file = "mGoToFolders.lua",
        },
        {
            title = "&Rebuild Stacks",
            file = "mRebuildStacks.lua",
        },
        {
            title = "&Update Stacks",
            file = "mUpdateStacks.lua",
        },
    },
    VERSION = { display = "2.2.7    Build: 2014-08-01 06:18:11" },
}
