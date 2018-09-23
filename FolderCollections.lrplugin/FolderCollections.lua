--[[
        FolderCollections.lua
--]]


local FolderCollections, dbg, dbgf = Object:newClass{ className = "FolderCollections", register = true }



--- Constructor for extending class.
--
function FolderCollections:newClass( t )
    return Object.newClass( self, t )
end


--- Constructor for new instance.
--
function FolderCollections:new( t )
    local o = Object.new( self, t )
    return o
end



-- get folder corresponding to collection, or set - leaf flag returned if special [folder] collection.
-- Note: this may be called 1st thing when auto-syncing, so it must be robust enough to do the right
-- thing regardless of source type.
-- Note: It's theoretically possible for coll-or-set to be plugin collection set, but it should really not be handled
-- by this method, so nil is returned to present disaster like trying to delete something that shouldn't be...
function FolderCollections:_getFolder( collOrSet, bg )
    local leafFlag
    local collOrSetType = cat:getSourceType( collOrSet )
    if collOrSetType == 'LrCollection' then
        local parent = collOrSet:getParent()
        if parent ~= nil then
            if parent.getName then
                if collOrSet:getName() == str:fmt( '[^1]', parent:getName() ) then
                    collOrSet = parent
                    leafFlag = true
                end
            else
                return nil -- this happens if collection is a direct descendent of catalog.
            end
        else -- I don't think this is possible, but hey...
            return nil
        end
    elseif collOrSetType == 'LrCollectionSet' then
        -- fine
    else
        Debug.pause( "Type should probably be pre-checked..." )
        return nil
    end
    local comps = { collOrSet:getName() } -- get-name will be there.
    local parent = collOrSet
    repeat
        if parent.getParent == nil then
            Debug.pause( "No get-parent" )
            return nil
        end
        parent = parent:getParent()
        if parent == self.pluginCollSet then
            break
        elseif parent == nil then
            return -- nil means not a folder-collection
        else
            comps[#comps + 1] = parent:getName()
        end
    until false
    comps[#comps + 1] = "" -- dummy - placeholder for root.
    tab:reverseInPlace( comps )
    for i, root in ipairs( self.roots ) do
        if root:sub( 1, 2 ) == "\\\\" then
            comps[1] = "" -- note: comp[2] will be "\{ntwork-drv-fldr-name}" but path needs to be "\\{ntwk-drv-fldr-name}\..." so setting [1] to "" means an extra path-sep gets prepended without duplicating the ntwk-drv-fldr-name
                -- kinda cheating I guess, but working @2/Jun/2014 23:39 ###1 (revisit & robusten?).
        else
            comps[1] = root
        end
        local path = str:componentsToPath( comps, app:pathSep() ) -- table.concat( comps, WIN_ENV and "\\" or "/" )
        --Debug.pause( path )
        local folder = cat:getFolderByPath( path, bg ) -- changed 27/May/2014 23:00 to use proxy method which works for unmapped network drives too ###3 (remove comment if no issues come 2016).
        if folder then
            --Debug.pause( path )
            if folder:getChildren() == nil then -- Lr mobile folder - won't return photos either, so..
                return nil, nil, str:fmt( "*** Folder '^1' is returning bad info (nil children array), due to a bug in Lightroom. If Lr mobile folder, this bug has already been reported, otherwise please let me know which folders are giving you this problem..", path )
            elseif folder:getPhotos( false ) == nil then -- renamed folder or parent
                return nil, nil, str:fmt( "*** Folder '^1' is returning bad info (nil photo array). If due to a certain bug in Lightroom (folder or parental folder has been renamed recently), restarting Lightroom will clear this condition - if not, then it's due to a different bug in Lightroom - please let me know which folders are giving you this problem..", path )
            else
                return folder, leafFlag
            end
        else -- ###4 for Wally:  (I no longer remember what the deal was with Wally..).
            --Debug.pauseIf( root:sub( 1, 2 )=="\\\\" and path:find( "\\_temp" ), path, comps[1], comps[2], comps[3], comps[4], comps[5], comps[6] )
            app:logV( "No folder in catalog at ^1", path )
        end
    end
    return false, leafFlag
end



-- call this before running mirror-folder op, or other service ops,
-- *** but: only AFTER pausing.
function FolderCollections:_initRun( call, bg )
    if not bg then cat:initFolderCache() end
    self.nAdds = 0
    self.nRmvs = 0
    self.nCollsDel = 0
    self.nSetsDel = 0
    self.nNoSels = 0
    self.nStacked = 0
    self.nToStack = 0
    self.collsVisited = {}
    self.service = call
    self:_computeRoots()
    self.initForRun = true
end



-- presently no way to get "drive" from a folder, except by parsing from path.
-- roots are used (trial and error) to reverse translate collection to folder.
function FolderCollections:_computeRoots()
    local rootSet = {}
    for i, f in ipairs( catalog:getFolders() ) do -- note: top-level catalog folders only - non-recursive.
        local path = f:getPath() -- reminder: if Lr mobile this will be \\dafdfkajfjdfh508945... i.e. only one level.
        local parent = str:parent( path ) -- get parent of path, without being fooled by network drive syntax. Note: if Lr mobile this will be \\
        -- not sure if I'll putting Mac users to pasture with this change, but I never tested it on Mac anyway, so maybe I'll find something out.. ###1
        if str:is( parent ) then
            rootSet[parent] = true -- root set is all parents of top-level catalog folders, in such a way that folders can be recreated from collection paths.
            app:logV( "Root: ^1", parent )
        else
            app:logE( "Can't get parent of catalog folder path (^1) - there's a good chance the corresponding collection will go \"poof\" during review/auto-mirror - please report problem, thanks..", path )
            -- unlike previous version - keep on truckin': better to function without a funky folder collection than go belly up, I hope.
        end
    end
    self.roots = tab:createArray( rootSet ) -- convert to desired format: array.
    --[[ ###1 - how it was before 2/Jun/2014 23:54 - mighty complicated.. - hopefully mostly if not entirely for naught..
        local rootLookup = {}
        self.roots = {}
        local function addRoot( root )
            if not rootLookup[root] then
                self.roots[#self.roots + 1] = root
                rootLookup[root] = true
                -- app:log( "Added root on behalf of ^1 (^2): ^3", name, _c, root )
                app:logV( "Added root: ^1", root ) -- ###4 Wally
            end
        end
        local root
        local folderName = str:leafName( path ) -- f:getName()
        local comps = str:splitPath( path )
        local path2 = str:makePathFromComponents( comps )
        app:assert( path2 == path, "path: '^1', path2: '^2'", path, path2 )
        local pcomps = str:splitPath( parent )
        local parent2 = str:makePathFromComponents( pcomps )
        --app:assert( root == parent2, "root: '^1', parent2: '^2'", root, parent2 )
        -- beware: C:\Users\{user}\Pictures\Lightroom\Mobile Uploads\af3277032d41bd4d21cbfd31463d7dee02d713db0bcca51e816c19aa883f69e3 being reported as
        -- or maybe it's C:\Users\{user}\Pictures\Lightroom\Mobile Downloads.lrdata\af3277032d41bd4d21cbfd31463d7dee02d713db0bcca51e816c19aa883f69e3 (not sure):
        -- \\af3277032d41bd4d21cbfd31463d7dee02d713db0bcca51e816c19aa883f69e3
        -- by lr-folder's get-path method.
        if #comps == 1 then -- when using split-path, this only happens if no slashes, I think.
            if comps[1] == path then
                app:error( "Invalid folder path: '^1' - if it is a parent, it needs to be hidden. If not a parent, then I'm not sure (please report problem), but something needs to be done with it for ^3 to function properly.", path, comps[1], app:getAppName() )
            else -- probably never happens:
                app:error( "Invalid folder path: '^1' - if this is a parent: '^2', then it needs to be hidden. If not a parent, then I'm not sure (please report problem), but something needs to be done with it for ^3 to function properly.", path, comps[1], app:getAppName() )
            end
        end
        --Debug.pause( #comps, path )
        local i = 1
        if WIN_ENV then
            if comps[1] == "\\\\" then
                app:logW( "folder path looks like a network drive (Lr mobile??) - such has not been tested - please let me know if you have a problem with this folder, or not: ^1", path )
            elseif comps[1] == "\\" then
                app:logW( "folder path looks like relative path - such was not expected - please let me know if you have a problem with this folder, or not: ^1", path )
            elseif comps[1]:sub(1,1) == "/" then -- using split-path, this should not happen in Windows.
                app:logE( "unable to split folder path (^1) into proper components - either wonky folder returned by Lightroom, or there is a bug in my splitter - please report this problem - thanks.", path )
            elseif comps[1]:sub( 2, 2 ) == ":" then -- folder looks like a normal drive-prefixed path.
                local c1 = comps[1]:sub( 1, 1 )
                if c1 >= "A" and c1 <= "Z"  then -- drive letter, capitalized (which I *think* they always will be).
                    -- this is normal - keep quiet
                else
                    app:logW( "Unexpected drive letter: '^1'  - such was not expected - please let me know if you have a problem with this folder, or not: ^2", c1, path )
                end
            else
                app:logW( "I was unable to split folder path (^1) into proper components - either wonky folder returned by Lightroom, or there is a bug in my splitter - please report this problem - thanks.", path )
            end
            root = comps[1]
        else -- @25/May/2012 1:10, not tested on Mac. ###1
            if comps[1] == "/" then
                Debug.pause( "Root of Mac folder path is root of drive." )
            else
                Debug.pause( "Root of Mac folder path is not root of drive - computing absolute root starting from drive root." )
            end
            root = "/"
        end
        repeat
            i = i + 1
            if comps[i] == nil then
                Debug.pause( path, folderName )
                app:error( "Unable to compute root for path: ^1", path )
            elseif folderName == comps[i] then
                app:logV( "Root: ^1", self.roots[#self.roots] or "nil" ) -- ###4 Wally
                break
            elseif comps[1] == "\\\\" then
                root = LrPathUtils.child( root, comps[i] )
            else
                --Debug.pause( folderName, comps[i] )
                root = LrPathUtils.child( root, comps[i] )
            end
        until false
        --Debug.pauseIf( root ~= parent, "root", root, "parent", parent )
        addRoot( root )
    end
    --]]
end



-- Deletes a collection or collection set item.
-- Guts are a simple call to item-delete. but with logging and naming and stats...
function FolderCollections:_deleteItem( item )
    local name = item:getName()
    local parent = item:getParent()
    if not parent or not parent.getName then
        -- it's a top-level item, do not delete.
        app:logWarning( "Top-level item not deleted." )
        return -- nil
    end
    local parentName = parent:getName()
    local s, m
    local itemType = cat:getSourceType( item )
    if itemType == 'LrCollection' then
        app:logVerbose( "Removing Collection '^1'", name )
        s, m = cat:update( 20, str:fmt( "Remove Collection ^1", name ), function( context, phase )
            item:delete()
        end )
        if s then
            self.nCollsDel = self.nCollsDel + 1
            app:log( "Collection (^1) deleted from '^2'", name, parentName, m )
        else
            app:logErr( "Unable to delete collection (^1) from '^2', error message: ^3", name, parentName, m )
        end
    elseif itemType == 'LrCollectionSet' then
        app:logVerbose( "Removing Collection Set '^1'", name )
        s, m = cat:update( 20, str:fmt( "Remove Collection Set ^1", name ), function( context, phase )
            item:delete()
        end ) 
        if s then
            self.nSetsDel = self.nSetsDel + 1
            app:log( "Collection set (^1) deleted from '^2'", name, parentName, m )
        else
            app:logErr( "Unable to delete collection set (^1) from '^2', error message: ^3", name, parentName, m )
        end
    else
        app:callingError( "Item is not a folder collection or set." )
    end
    return s -- m is logged before return.
end



--[[
        Assure a folder collection or set which mirrors the specified lr-folder.
        
        Used for initial building, as well as maintenance, passing root, or subfolder...
        
        Two parts:
        ----------
            1. Create coll sets / colls, and create/populate as need be.
            2. Review coll sets / colls, and remove extraneous photos and/or collections / sets.
            
        param lrFolder (LrFolder or LrCatalog)
        param collOrSet (LrCollectionSet) plugin collection set or collection corresponding to lr-folder.
        
        returns parent of source if converted or deleted.
--]]
function FolderCollections:_mirrorFolder( lrFolder, collOrSet, leaf )
    if lrFolder == nil then
        app:logWarning( "^1 is not in folder collection tree.", collOrSet.getName and collOrSet:getName() or "Top-level item" )
        return
    elseif lrFolder == false then -- nil means collOrSet *not* in folder collections tree - do *not* delete!
        local parent = collOrSet:getParent()
        self:_deleteItem( collOrSet )
        return parent
    end
    -- Add photos to folder collection.
    -- * create collection if necessary in parent set.
    local function addToColl( folder, parent, forceLeaf )
        assert( parent.getName ~= nil, "No parent name" )
        assert( folder.getName ~= nil, str:fmt( "No folder name corresponding to set: ^1", parent:getName() ) )
        app:logVerbose( "Adding to collection, parent: '^1', folder: '^2'", parent:getName(), folder:getName() )
        local coll -- this coll is on the level with folder.
        local toAdd = {}
        local s, m = cat:update( 20, "Assure Folder Collection", function( context, phase )
            -- *** Save for reminder: coll = catalog:createSmartCollection( folder:getName(), searchDesc, parent, true ) - not doable because no way to reliably match folder path.
            -- Note: it would be possible now that I think about it, to use a dynamix-like technique: updating a match var upon which the smart-coll is based,
            -- but it would not be nearly responsive enough. Although, perhaps if it was dedicated, and used techniques like John Ellis did for any-filter:
            -- Calling find-photos repeatedly based on each path component. - may be some potential there: needs more thought. For example, use smart collection
            -- based on contains-words of each component, which casts too wide a net, then use match var to weed out the excess - hmmmm.......
            if phase == 1 then
                local name = folder:getName()
                if leaf or forceLeaf then
                    name = str:fmt( '[^1]', name )
                end
                coll = catalog:createCollection( name, parent, true ) -- this is the collection which needs to be reverse translatable into the correct folder.
                return false -- keep going.
            elseif phase == 2 then
                local collPhotos = coll:getPhotos()
                if #collPhotos > 0 then
                    local collPhotoSet = tab:createSet( collPhotos )
                    local photos = folder:getPhotos( false )
                    if photos ~= nil then -- folder is ok
                        for i, photo in ipairs( photos ) do
                            if not collPhotoSet[photo] then
                                toAdd[#toAdd + 1] = photo
                            end
                        end
                    elseif folder:getChildren() == nil then
                        app:logV( "*** Bug in Lightroom - if Lr mobile folder, it's already been logged, if not: do tell..", folder:getPath() or "Lr not giving path - ugh" )
                    else
                        app:logE( "A folder (or it's parent) has probably been renamed recently (current name is '^1'). Due to a bug in Lightroom, you may need to restart Lightroom to clear this condition.", folder:getName() or "Lr not giving name - ugh" )
                    end
                else
                    toAdd = folder:getPhotos( false )
                    if toAdd ~= nil then -- should always be true, but isn't.
                        -- good
                    elseif folder:getChildren() == nil then
                        app:logV( "*** Bug in Lightroom - if Lr mobile folder, it's already been logged, if not: do tell..", folder:getPath() or "Lr not giving path - ugh" )
                        toAdd = {}
                    else
                        toAdd = {}
                        app:logE( "A folder (or it's parent) has probably been renamed recently (current name is '^1'). Due to a bug in Lightroom, you may need to restart Lightroom to clear this condition.", folder:getName() or "Lr not giving name" )
                    end
                end
                if #toAdd > 0 then -- upvalue nil?
                    coll:addPhotos( toAdd )
                end
                return true -- done
            else
                --Debug.pause( "Catalog update phase out of range:", phase )
                app:error( "Catalog update phase out of range: ^1", phase )
            end
        end )
        if s then
            self.nAdds = self.nAdds + #toAdd
            app:logVerbose( "Assured folder collection: ^1", coll:getName() )
            return coll
        else
            return nil, m
        end
    end
    -- This function is called to create or assure a folder collection set that matches folder, parent set required for creation / assurance.
    -- Only adds photos to [folder] collection if they don't already exist.
    local function addToSet( folder, parent )
        -- Debug.logn( "set-parent", parent:getName(), "set", folder:getName() )
        app:logVerbose( "Adding folder collection set '^1' to '^2'", folder:getName(), parent:getName() )
        local set
        local coll
        local noSubfolders
        local leafPhotos
        local toAdd = {}
        local s, m = cat:update( 20, "Assure Folder Collection Set", function( context, phase )
            if phase == 1 then
                set = catalog:createCollectionSet( folder:getName(), parent, true )
                return false
            elseif phase == 2 then
                leafPhotos = folder:getPhotos(false)
                if leafPhotos ~= nil then
                    if #leafPhotos > 0 then
                        return false
                    else
                        return true
                    end
                elseif folder:getChildren() == nil then
                    app:logV( "*** Bug in Lightroom - if Lr mobile folder, it's already been logged, if not: do tell..", folder:getPath() or "Lr not giving path - ugh" )
                    Debug.pause()
                    return true -- I guess
                else
                    app:logErr( "A folder has probably been renamed recently (current name is '^1'). Due to a bug in Lightroom, you may need to restart Lightroom to clear this condition.", folder:getName() or "Lr not giving name - argh" )
                    return true -- unfortunately, done.
                end
            elseif phase == 3 then
                coll = catalog:createCollection( str:fmt( '[^1]', folder:getName() ), set, true ) -- ditto (reverse translate).
                app:logVerbose( "Created/assured \"Folder Leaf Photos\" collection ^1 in '^2'", folder:getName(), set:getName() )
                return false
            elseif phase == 4 then
                local collPhotos = coll:getPhotos()
                if #collPhotos > 0 then
                    local collPhotoSet = tab:createSet( collPhotos )
                    assert( leafPhotos ~= nil, "no leaf photos" )
                    for i, photo in ipairs( leafPhotos ) do
                        if not collPhotoSet[photo] then
                            toAdd[#toAdd + 1] = photo
                        end
                    end
                else
                    toAdd = leafPhotos
                end
                if #toAdd > 0 then
                    coll:addPhotos( toAdd )
                end
                return true
            elseif phase == 5 then
                toAdd = leafPhotos -- for stats
                coll:addPhotos( toAdd )
                return true                
            else
                --Debug.pause( "Catalog update phase out of range", phase )
                app:error( "Catalog update phase out of range: ^1", phase )
            end
        end )
        if s then
            app:logVerbose( "Assured collection set: ^1", set:getName() )
            if #toAdd > 0 then
                self.nAdds = self.nAdds + #toAdd
                app:logVerbose( "Added ^1 to folder photo (leaf) collection.", str:plural( #toAdd, "photo", true ) )
            end
            return set
        else
            return nil, m
        end
    end
    -- Creates or assure each child folder exists as collection/set, and has missing photos added if need be. parent is collection set.
    local function addToChildren( folders, parent )
        app:logVerbose( "Adding to children, parent: ^1", parent:getName() )
        assert( folders ~= nil, "no folders" )
        for i, folder in ipairs( folders ) do
            if self.service ~= nil then -- ###2 always non-nil now (consider less obtrusive caption if startup (call is from background).
                self.service.scope:setCaption( "Populating " .. folder:getName() )
            end
            local children = folder:getChildren()
            if children ~= nil then -- array
                if #children > 0 then
                    local set, m = addToSet( folder, parent )
                    if set then
                        addToChildren( children, set )
                    else
                        app:logErr( m )
                    end
                else
                    local coll, m = addToColl( folder, parent )
                    if coll then
                        --
                    else
                        app:logErr( m )
                    end
                end
            else -- this is a departure from previous alpha release (2.2.5.3), which would have added folder to collection instead, but I can't see the reason to do so, since it is generally removed later anyway, and so far if no children no photos either so kinda useless..
                -- log pseudo error instead of real error, since this will be recurring, maybe a *lot*.
                app:logV( "*** Folder '^1' is returning bad info (nil children array), due to a bug in Lightroom. If Lr mobile folder, this bug has already been reported, otherwise please let me know which folders are giving you this problem..", folder:getPath() or "no path info obtainable" )
            end
            if self.service ~= nil then
                if self.service:isQuit() then
                    return
                else
                    -- self.service:setPortionComplete
                end
            else
            
            end
        end
    end
    -- remove photos from collection which no longer exist in folder.
    -- Note: this function is a tad different than add-to-coll, in that collection is sibling, not parent.
    local function removeFromColl( folder, coll )
        app:logVerbose( "Purging collection: '^1', folder: '^2'", coll:getName(), folder:getName() )
        local rmv = {}
        local collPhotos = coll:getPhotos()
        local photos = folder:getPhotos( false )
        if photos ~= nil then -- bug in Lightroom @4.1.
            -- good
        elseif folder:getChildren() == nil then
            Debug.pause()
            app:logV( "*** Bug in Lightroom - if Lr mobile folder, it's already been logged, if not: do tell..", folder:getPath() or "Lr not giving path - ugh" )
            return
        else
            app:logErr( "A folder has probably been renamed recently (current name is '^1'). Due to a bug in Lightroom, you may need to restart Lightroom to clear this condition.", folder:getName() or "Lr not giving name - dangit" )
            return -- no point removing photos based on a screwed up folder object.
        end
        local folderPhotoSet = tab:createSet( photos )
        assert( collPhotos ~= nil, "no coll photos" )
        for i, collPhoto in ipairs( collPhotos ) do
            if folderPhotoSet[collPhoto] then -- photo is in folder still
                -- app:logVerbose( "F
            else
                rmv[#rmv +  1] = collPhoto
            end
        end
        if #rmv > 0 then
            local s, m = cat:update( 20, "Remove Photos", function( context, phase )
                coll:removePhotos( rmv )
            end )
            if s then
                app:log( "Removed ^1 from ^2", #rmv, coll:getName() )
                self.nRmvs = self.nRmvs + #rmv
            else
                app:logErr( m )
            end
        else
        end
    end
    -- remove extraneous photos or collections, or collection sets from collection set, if not matched in folder tree.
    -- may be called recursively.
    local function removeFromChildren( folder, collSetChildren )
        if folder.getName then
            app:logVerbose( "Purging collection children based on folder: '^1'", folder:getName() )
        else
            app:logVerbose( "Purging collection children based on catalog as root folder." )
        end
        assert( collSetChildren ~= nil, "no coll set children" )
        for i, item in ipairs( collSetChildren ) do
            local name = item:getName()
            if self.service ~= nil then
                self.service.scope:setCaption( "Reviewing " .. name )
            end
            local subfolder, leaf, errm = self:_getFolder( item )
            if subfolder then
                -- Debug.pause( subfolder )
                if cat:getSourceType( item ) == 'LrCollection' then
                    removeFromColl( subfolder, item )
                else
                    removeFromChildren( subfolder, item:getChildren() ) -- coll-set's children, not folder's children.
                end
            elseif subfolder == false then
                if name:sub( 1, 2 ) == "\\\\" then
                    dbgf( "no subfolder for collection set or collection representing network drive, item-name: ^1 - deleting corresponding coll/set item..", name )
                end
                self:_deleteItem( item )
            elseif errm then -- it's probably the nil children or nil photos problem.
                if errm:sub( 1, 3 ) == "***" then -- above-mentioned pseudo error for sure.
                    app:logV( errm )
                else
                    Debug.pause() -- I dont think this is happening.
                    app:logE( errm )
                end
            -- else dont sweat..
            end
            if self.service ~= nil then
                if self.service:isQuit() then
                    return
                else
                    -- self.service:setPortionComplete
                end
            else
            
            end
        end
    end
    
    -- main function logic
    if cat:getSourceType( collOrSet ) == 'LrCollection' then
        local coll = collOrSet
        -- note: collection may need to be converted to set, if a folder was added to source.
        local subfolders = lrFolder:getChildren()
        if subfolders ~= nil then
            if #subfolders > 0 then
                if not leaf then -- if we're syncing a collection which is not the leaf collection (which syncs to parent folder), and source has subfolders, it needs to be a set, and set must be mirrored correctly...
                    local set = self:_convertCollToSet( coll, lrFolder )
                    self:_mirrorFolder( lrFolder, set )
                    return set
                else -- whether leaf is still warranted depends on photo-count, not subfolder count.
                    local photos = lrFolder:getPhotos( false )
                    if photos ~= nil then 
                        -- good
                    else -- bug in Lightroom @4.1
                        -- reminder: folder--get-children is not nil.                    
                        app:logE( "A folder has probably been renamed recently (current name is '^1'). Due to a bug in Lightroom, you may need to restart Lightroom to clear this condition.", lrFolder:getName() or "Lr not giving name - hmm" )
                        return
                    end
                    if #photos > 0 then -- leaf collection still warranted.
                        local coll = addToColl( lrFolder, coll:getParent() ) -- leaf as passed, is true, adds any photos to coll that are in folder.
                        if coll then
                            removeFromColl( lrFolder, coll )
                        else
                            app:logWarning( "No collection for reviewing: ^1", lrFolder.getName and lrFolder:getName() or "top-level" )
                        end
                    else
                        local parent = coll:getParent()
                        local deleted = self:_deleteItem( coll )
                        if deleted then
                            return parent
                        -- else msg already logged
                        end
                    end
                end
            else
                -- collection, and folder has no subfolders.
                local photos = lrFolder:getPhotos( false )
                if photos ~= nil then
                    if #photos > 0 then
                        addToColl( lrFolder, coll:getParent() ) -- leaf as passed, adds any photos to coll that are in folder.
                        removeFromColl( lrFolder, coll )
                    else -- no photos in folder => leaf: delete, else remove-all.
                        local collPhotos = coll:getPhotos()
                        if leaf then -- empty collections are hunky-dory, as long as not a leaf collection
                            local photos = coll:getPhotos()
                            local set = coll:getParent()
                            local s, m = cat:update( 20, "Remove Folder (Leaf) Collection", function( context, phase )
                                if phase == 1 and #photos > 0 then
                                    coll:removeAllPhotos()
                                    return false
                                else
                                    coll:delete()
                                end
                            end )
                            return set
                        else
                            local s, m = cat:update( 20, "Remove Photos from Folder Collection", function( context, phase )
                                coll:removeAllPhotos()
                            end )
                            -- done.
                        end
                    end
                else -- reminder: lr-folder--get-children is not nil
                    app:logE( "A folder has probably been renamed recently (current name is '^1'). Due to a bug in Lightroom, you may need to restart Lightroom to clear this condition.", lrFolder:getName() or "Lr not giving name - thppp.." )
                    return
                end
            end
        else
            app:logV( "*** Folder '^1' is returning bad info (nil children array), due to a bug in Lightroom. If Lr mobile folder, this bug has already been reported, otherwise please let me know which folders are giving you this problem..", lrFolder:getPath() or "no path info obtained" )        
        end
    else -- folder collection set (lr-folder may be catalog, or folder, coll-or-set may be base plugin collection set, or subset).
        local set = collOrSet
        local subfolders
        local photos
        if lrFolder.getFolders then -- catalog
            assert( set == self.pluginCollSet, "mismatch" )
            subfolders = lrFolder:getFolders()
            photos = {} -- a little trick to keep from trying to add a leaf collection corresponding to catalog.
            if #subfolders == 0 then
                local childSets = set:getChildCollectionSets()
                local childColls = set:getChildCollections()
                if #childSets == 0 and #childColls == 0 then
                    -- sync'd.
                else
                    local s, m = cat:update( 20, "Remove Folder Collection Sets", function( context, phase )
                        assert( childSets~= nil, "no child sets" )
                        assert( childColls~= nil, "no child colls" )
                        for i, child in ipairs( childSets ) do
                            self:_deleteItem( child )
                        end
                        for i, child in ipairs( childColls ) do
                            self:_deleteItem( child )
                        end
                    end )
                    if s then
                        app:log( "Removed all items from plugin collection set, since no folders in catalog." )
                    else
                        app:logErr( m )
                    end
                end
                return set
            -- else fall-through and sync like any other.
            end
        else
            subfolders = lrFolder:getChildren()
            photos = lrFolder:getPhotos( false )
            if photos ~= nil then
                -- good
            elseif subfolders ~= nil then -- bug in Lightroom @4.1
                -- reminder subfolders nil is handled below.
                app:logE( "A folder has probably been renamed recently (current name is '^1'). Due to a bug in Lightroom, you may need to restart Lightroom to clear this condition.", lrFolder:getName() or "Lr not giving name!" )
                return
            end
        end
        if subfolders ~= nil then
            if #subfolders == 0 then -- no subfolders, means set should be a collection.
                -- Note: set will NOT be plugin collection set in this case.
                local coll = self:_convertSetToColl( set, lrFolder )
                addToColl( lrFolder, coll:getParent() ) -- leaf as passed, adds any photos to coll that are in folder.
                return coll
            else -- has subfolders.
                if #photos > 0 then -- has photos too
                    local coll, m = addToColl( lrFolder, set, true ) -- force-leaf
                    if coll then
                        removeFromColl( lrFolder, coll, true ) -- force-leaf
                    else
                        app:logErr( m )
                    end
                else -- delete leaf coll if it exists
                    if lrFolder.getName then -- not catalog
                        local name = lrFolder:getName()
                        name = str:fmt( '[^1]', name )
                        local colls = collOrSet:getChildCollections()
                        assert( colls~=nil, "no colls" )
                        for i, v in ipairs( colls ) do
                            if name == v:getName() then
                                self:_deleteItem( v )
                            else
                                Debug.logn( v:getName(), name )
                            end
                        end
                    end
                end
                --Debug.pause()
                addToChildren( subfolders, set ) 
                removeFromChildren( lrFolder, set:getChildren() )
            end
        else
            app:logV( "*** Folder '^1' is returning bad info (nil data), due to a bug in Lightroom. If Lr mobile folder, this bug has already been reported, otherwise please let me know which folders are giving you this problem..", lrFolder:getPath() or "no path info obtained" )        
        end
    end
end



-- called by background init, wrapped in a pcall which just declares failed initialization if any errors thrown.
function FolderCollections:init( call )
    -- this until 26/Apr/2013 21:13 - self:_initRun() -- does not use background call object, or scope.
    self:_initRun( call ) -- this after 26/Apr/2013 21:13.
    -- Debug.showLogFile()
    self.pluginCollSet = cat:assurePluginCollectionSet()    
    assert( self.pluginCollSet ~= nil, "no pcs" ) -- protected call from init task.
    local answer = 'ok'
    local initialBuild = false
    local folders = catalog:getFolders()
    if #self.pluginCollSet:getChildren() == 0 then
        if #folders > 0 then
            answer = app:show{ confirm="Build folder collections?\n\nAfter initial build, they will be updated automatically each time the plugin is reloaded (e.g. when Lightroom starts) - and future updates will be much quicker than initial build.\n\nSelected folder collections are synchronized with source folder automatically, by default, but parental folder collection sets, when selected, will not be synchronized - please visit plugin manager to change such stuff..." }
            initialBuild = true
        else
            app:log( "No folders." )
            return -- no folders either place.
        end
    end
    if answer == 'ok' then
        self:_mirrorFolder( catalog, self.pluginCollSet, nil ) -- , initialBuild ) -- like -build, except without the wrapper and the bg-pause.
    else
        return -- not going to raise a fuss...
    end
    local children = self.pluginCollSet:getChildren()
    if #children > 0 then
    
        if WIN_ENV then

            local answer = app:show{ confirm="Do you want stacks in folder collections to be same as stacks in folders? - me too, but answer 'No' unless you are willing to let it run without interference for a long while, before you use your computer at all - Lightroom, or any other apps!\n \n*** Note: stacking via this plugin is deprecated in favor of stacking via the Stacker plugin, where it has been done more robustly/reliably. Still, if it's been working for you here, go to it...\n \nNote2: the 'No' answer is \"remember-able\" too ;-}",
                buttons = { dia:btn( "Yes - Rebuild", 'ok' ), dia:btn( "Yes - Update", 'other' ), dia:btn( "No", 'cancel' ) },
                actionPrefKey = "Mirror stacks - deprecated",
            }
            if answer == 'ok' or answer == 'other' then
                local selPhotos = cat:saveSelPhotos() -- and view filter.
                if app:getPref( 'assumeGlobalLibFilter' ) then
                    cat:clearViewFilter()
                end
                local s, m = self:_mirrorStacks( answer == 'ok', self.pluginCollSet, call )
                cat:restoreSelPhotos( selPhotos ) -- and view filter.
                if s then
                    app:logv( "stacks mirrored, original photo selection restored" )
                else
                    app:show{ error="Unable to mirror stacks - ^1", m }
                end
            else
                app:log( "User opted out of mirroring stacks upon startup." )
            end
            
        -- else not supported on mac yet.
        end
    end    
    if initialBuild then
        if #children > 0 then
            local answer = app:show{ confirm="Folder collections have been built - go there now?" }
            if answer == 'ok' then
                catalog:setActiveSources{ self.pluginCollSet }
            end
        else
            if #folders > 0 then
                app:show{ warning="No folder collections were built - please see log file..." }
            else
                app:logWarning( "Catalog has no folders - neither does ^1 collection set.", app:getPluginName() )
                    -- mirror was only initiated if there was folders or folder collections, so issue a warning.
            end
        end
    end
    --Debug.showLogFile()
end



-- Supports file-menu (and same in plugin manager) functions:
-- 'Rebuild' & 'Update'.
function FolderCollections:build(fromScratch)
    app:call( Service:new{ name="Build Folder Collections", async=true, progress=true, guard=App.guardVocal, main=function( call )
        local s, m = background:pause()
        if s then
            self:_initRun( call )
            -- Note: init does not succeed if plugin-coll-set not creatable, but since this method can be called even when plugin is disabled in plugin manager,
            -- it's worth an extra check.
            if fromScratch and self.pluginCollSet then
                local s, m = cat:update( 20, "Delete Folder Collection Sets", function( context, phase )
                    self.pluginCollSet:delete()
                end )
            end
            self.pluginCollSet = cat:assurePluginCollectionSet() -- error if no can do.
            self:_mirrorFolder( catalog, self.pluginCollSet )
            if not call:isQuit() then
                call.scope:setCaption( "Checking integrity and completeness..." )
                local report = self:_integrityCheck( call )
                if not call:isQuit() then
                    if report.nTotalPhotosShy ~= 0 then
                        app:log( "Folder collections are ^1 shy - means (possibly insignificant) anomaly in catalog, or bug in this plugin.", str:plural( report.nTotalPhotosShy, "photo", true ) )
                        app:show{ info="Folder collections are ^1 shy - which means there is a (possibly insignificant) anomaly in your catalog, or a bug in this plugin.",
                            subs = str:plural( report.nTotalPhotosShy, "photo", true ),
                            actionPrefKey = "Folder collections are shy",
                        }
                    else
                        app:log()
                        app:log( "All photos in catalog are represented in folder collections." )
                    end
                -- else is-quit.
                end
            -- else...
            end
        else
            app:show{ error="Unable to pause background task, error message: ^1", m }
        end
    end, finale=function( call )
        self:logStats()
        if app:getPref( 'background' ) then
            background:continue() -- if appropriate.
        end
    end } )
end



-- Supports file-menu (and same function in plugin manager) function.
function FolderCollections:syncSelected()
    app:call( Service:new{ name="Sync Selected", async=true, progress=true, guard=App.guardVocal, main=function( call )
        local s, m = background:pause()
        if s then
            self:_initRun( call )
            local sources = catalog:getActiveSources()
            local answer = app:show{ confirm="Sync ^1?", 
                subs = str:plural( #sources, "selected source", true ),
                actionPrefKey = "Sync selected sources",
            }
            if answer == 'cancel' then
                call:cancel()
                return
            end
            for i, source in ipairs( sources ) do
                local sourceType = cat:getSourceType( source )
                if sourceType == 'LrCollection' or sourceType == 'LrCollectionSet' then
                    local folder, leaf, errm = self:_getFolder( source ) -- not bg task, so use folder cache.
                    if not str:is( errm ) then
                        self:_mirrorFolder( folder, source, leaf )
                    else -- invalid folder corresponding to source.
                        if errm:sub( 1, 3 ) == "***" then
                            app:logV( errm )
                        else
                            Debug.pause() -- I dont think this is happening.
                            app:logE( errm )
                        end
                    end
                elseif sourceType == 'LrFolder' then
                    -- local parentCollSet = ###2
                    -- self:_mirrorFolder( source, parentCollSet )
                    app:logWarning( "@24/May/2012, source must be folder collection or set, not folder proper. Consider re-building folder collections, or sync parental folder collection set instead. - this may change in the future..." )
                else
                    app:logWarning( "Active source is not sync-able, ignoring '^1'", cat:getSourceName( source ) )
                end
            end
        else
            app:show{ error="Unable to pause background task, error message: ^1", m }
        end
    end, finale=function( call )
        self:logStats()
        if app:getPref( 'background' ) then
            background:continue() -- if appropriate.
        end
    end } )
end



-- Supports file-menu (and same function in plugin manager) function.
function FolderCollections:goToFolders()
    app:call( Service:new{ name="Go To Folders", async=true, progress=true, guard=App.guardVocal, main=function( call )
        local s, m = background:pause()
        if s then
            self:_initRun( call )
            local sources = catalog:getActiveSources()
            local answer = app:show{ confirm="Go to folders corresponding to ^1?", 
                subs = str:plural( #sources, "selected source", true ),
                actionPrefKey = "Go to folders",
            }
            if answer == 'cancel' then
                call:cancel()
                return
            end
            local folders = {}
            for i, source in ipairs( sources ) do
                local sourceType = cat:getSourceType( source )
                if sourceType == 'LrCollection' or sourceType == 'LrCollectionSet' then
                    local folder, leaf, errm = self:_getFolder( source ) -- not bg, so use folder cache.
                    if folder then
                        folders[#folders + 1] = folder
                    elseif folder == false then -- source no longer exists, or is-leaf and no longer has photos.
                        local parent = source:getParent()
                        local deleted
                        local sourceName = source:getName()
                        local s, m = cat:update( 20, "Remove Collection or Set", function( context, phase )
                            deleted = self:_deleteItem( source )
                        end )
                        if s then
                            local parentName
                            if parent and parent.getName then
                                if deleted then
                                    parentName = parent:getName()
                                    app:logWarning( "Removed '^1' - consider syncing parent: '^2'", sourceName, parentName )
                                -- else warning already logged.
                                end
                            else
                                if deleted then
                                    app:logWarning( "Removed '^1' - consider re-building or updating folder collections.", sourceName )
                                -- else warning already logged.
                                end
                            end
                        else
                            app:logErr( m )
                        end
                    elseif errm then
                        if errm:sub( 1, 3 ) == "***" then
                            app:logV( errm )
                        else
                            Debug.pause() -- I dont think this is happening.
                            app:logE( errm )
                        end
                    end
                elseif sourceType == 'LrFolder' then
                    -- local parentCollSet = ###2
                    -- self:_mirrorFolder( source, parentCollSet )
                    app:logWarning( "@24/May/2012, source must be folder collection or set, not folder proper. Consider re-building folder collections, or sync parental folder collection set instead. - this may change in the future..." )
                -- else not applicable
                end
            end
            if #folders > 0 then
                catalog:setActiveSources( folders )
            else
                app:show{ warning="No corresponding folders - consider selecting different source, or re-building folder collections." }
            end
        else
            app:show{ error="Unable to pause background task, error message: ^1", m }
        end
    end, finale=function( call )
        self:logStats()
        if app:getPref( 'background' ) then
            background:continue() -- if appropriate.
        end
    end } )
end



-- 'Report' function, called from plugin manager, to compare photos in folders, to photos in folder collections.
-- @25/May/2012 21:51, simply compares catalog photo count to sum of all photos in folder collections.
function FolderCollections:_integrityCheck( call )
    
    app:log( "Doing general integrity check." )
    local nPhotos2 = 0
    local doColl, doColls, doCollSets
    function doColl( f )
        app:logVerbose( "Accounting for ^1", f:getName() )
        nPhotos2 = nPhotos2 + #f:getPhotos() -- reminder: f is a collection, not a folder, so not subject to same get-photos bug as folder object.
    end
    function doColls( fs )
        for i, f in ipairs( fs ) do
            doColl( f )
        end
    end
    function doCollSets( cs )
        for i, f in ipairs( cs ) do
            doCollSets( f:getChildCollectionSets() )
            doColls( f:getChildCollections() )
            if call:isQuit() then return end
        end
    end
    local nPhotos = #catalog:getAllPhotos()
    doCollSets( self.pluginCollSet:getChildCollectionSets() )
    doColls( self.pluginCollSet:getChildCollections() )
    local diff = nPhotos - nPhotos2
    if diff == 0 then
        app:log( "General integrity check done - no discrepancy." )
    else
        app:log( "*** General integrity check done, discrepancy: ^1", diff )
    end
    return {
        nPhotosInFolders = nPhotos,
        nPhotosInFolderCollections = nPhotos2,
        nTotalPhotosShy = diff,
    } -- Note calling context, deals with results.
end


function FolderCollections:_getPath( collOrSet )
    local comp = { collOrSet:getName() }
    parent = collOrSet:getParent()
    while parent and parent.getName do
        comp[#comp + 1] = parent:getName()
        if parent.getParent then
            parent = parent:getParent()
        else
            break
        end
    end
    tab:reverseInPlace( comp )
    return table.concat( comp, "/" )
end



function FolderCollections:_isLeafOf( coll, set )
    local collName = coll:getName()
    if collName:sub( 1, 1 ) == '[' then
        if collName:sub( -1 ) == ']' then
            if collName:sub( 2, collName:len() - 1 ) == set:getName() then
                return true
            end
        end
    end
end



-- This function thoroughly scrutinizes folders compared to folder collections to detect any potential anomaly...
function FolderCollections:_scrutinizeThoroughly( call )
    
    app:log()
    local report = self:_integrityCheck( call )
    if report.nTotalPhotosShy ~= 0 then
        if report.nTotalPhotosShy > 0 then
            app:logWarning( "Folder collections are ^1 shy - means (possibly insignificant) anomaly in catalog, or bug in this plugin.", str:plural( report.nTotalPhotosShy, "photo", true ) )
        else
            app:logWarning( "Folder collections are ^1 fat - means (possibly insignificant) anomaly in catalog, or bug in this plugin.", str:plural( -report.nTotalPhotosShy, "photo", true ) )
        end
    else
        app:logVerbose( "Same number of photos in catalog are represented in folder collections." )
    end
    app:log()
    
    
    local folderInfo = {} -- array of all folders.
    --local foldersDone = {}
    local nFoldersToScrut = 0
    local scrutColls = {}
    local scrutSets = {}
    local setsWithMissingFolders = {}
    local collsWithMissingFolders = {}
    local orphSets = {}
    local orphColls = {}
    local setsGood = {}
    local collsGood = {}

    -- first, folder driven    
    local doFolder, doFolderChildren, doFolders
    function doFolder( f )
        app:logVerbose( "Catalog folder to scrutinize: ^1", f:getName() )
        local children = f:getChildren()
        local photos = f:getPhotos( false )
        if photos == nil then -- bug
            if children ~= nil then
                app:logE( "A folder has probably been renamed recently (current name is '^1'). Due to a bug in Lightroom, you may need to restart Lightroom to clear this condition.", f:getName() or "Lr not giving name, yet.." )
            end
            photos = {} -- OK for reporting purposes.
        end
        if children == nil then
            app:logV( "*** Folder '^1' is returning bad info (nil children array), due to a bug in Lightroom. If Lr mobile folder, this bug has already been reported, otherwise please let me know which folders are giving you this problem..", f:getPath() or "no path info obtained" )
            children = {} -- OK for reporting purposes.
        end
        folderInfo[f] = { subfolderCount=#children, photoCount=#photos, checkCount = 0 }
        nFoldersToScrut = nFoldersToScrut + 1
    end
    function doFolders( cs ) -- cs is folder children
        if cs == nil then
            app:logV( "*** Lr bug: folder children array is nil" )
            return
        end
        for i, f in ipairs( cs ) do
            doFolder( f )
            doFolders( f:getChildren() )
            if call:isQuit() then return end
        end
    end
    local function isPhotoCollPresent( set )
        for _, coll in ipairs( set:getChildCollections() ) do
            if self:_isLeafOf( coll, set ) then
                return #coll:getPhotos()
            end
        end
    end
    local function scrutinizePair( folder, leaf, collOrSet, isSet )
        if folderInfo[folder] then
            if isSet then
                local set = collOrSet
                app:logVerbose( "Scrutinizing folder/set pair, folder: ^1, collection set: ^2", folder:getPath(), set:getName() )
                if leaf then
                    app:logWarning( "Leaf not expected." )
                else
                    -- good
                end
                local nPhotos = isPhotoCollPresent( set )
                if nPhotos ~= nil then -- photo coll found
                    if nPhotos ~= folderInfo[folder].photoCount then
                        if folderInfo[folder].photoCount > nPhotos then
                            -- leaf coll is shy
                        else
                            -- leaf coll is fat.
                        end
                    else
                        --
                    end
                elseif folderInfo[folder].photoCount == 0 then
                    -- good
                else
                    app:logWarning( "Folder (leaf) collection set is missing." )
                end
                scrutSets[#scrutSets + 1] = collOrSet
            else
                local coll = collOrSet
                app:logVerbose( "Scrutinizing folder/collection pair, folder: ^1, collection: ^2", folder:getPath(), coll:getName() )
                local isLeaf = self:_isLeafOf( coll, coll:getParent() )
                if leaf then
                    if isLeaf then
                        app:logVerbose( "Got leaf, folder: ^1, coll: ^2", folder:getPath(), coll:getName() )
                        folderInfo[folder].isLeaf = true
                    else
                        app:logWarning( "Expected leaf collection, but '^1' is not.", coll:getName() )
                    end
                else
                    if isLeaf then
                        app:logWarning( "Expected not leaf collection, but '^1' is.", coll:getName() )
                    else
                        -- app:logVerbose( "Not leaf, folder: ^1, coll: ^2", folder:getPath(), coll:getName() )
                    end
                end
                local _photos = folder:getPhotos( false )
                local nPhotos
                if _photos ~= nil then
                    nPhotos = #_photos
                elseif folder:getChildren() == nil then
                    Debug.pause()
                    app:logV( "*** Bug in Lightroom - if Lr mobile folder, it's already been logged, if not: do tell..", folder:getPath() or "Lr not giving path - ugh" )
                    nPhotos = 0
                else -- ###1 is it *any* folder? or just the named folder whose renaming would cause such a thing
                    app:logE( "A folder has probably been renamed recently (current name is '^1'). Due to a bug in Lightroom, you may need to restart Lightroom to clear this condition.", folder:getName() or "Lr not giving name by gol" )
                    nPhotos = 0 -- for scrut purposes...
                end
                local nRep = #coll:getPhotos()
                if nRep == nPhotos then
                     -- good
                else
                    app:logWarning( "^1 has ^2, but ^3 has ^4", folder:getName(), nPhotos, coll:getName(), nRep )
                end
                scrutColls[#scrutColls + 1] = collOrSet
            end
            folderInfo[folder].checkCount = folderInfo[folder].checkCount + 1
        else
            if isSet then
                app:logWarning( "Orphan folder collection set: ^1", collOrSet:getName() )
                orphSets[#orphSets + 1] = collOrSet
            else
                app:logWarning( "Orphan folder collection: ^1", collOrSet:getName() )
                orphColls[#orphColls + 1] = collOrSet
            end
        end
    end
    local function scrutinizeMissingFolder( collOrSet, isSet )
        app:log( "Missing folder: ^1", collOrSet:getName() )
        if isSet then
            setsWithMissingFolders[#setsWithMissingFolders + 1] = collOrSet
        else
            collsWithMissingFolders[#collsWithMissingFolders + 1] = collOrSet
        end
    end
    local function scrutinizeInvalidColl( c )
        app:logWarning( "Invalid coll: ^1", c:getName() )
    end
    local function scrutinizeInvalidCollSet( c )
        app:logWarning( "Invalid coll set: ^1", c:getName() )
    end
    local doColl, doCollSet, doColls, doCollSets
    function doColl( c )
        app:log( "Folder Collection being scrutinized: ^1", c:getName() )
        local folder, leaf, errm = self:_getFolder( c )
        if folder then
            scrutinizePair( folder, leaf, c, false )
        elseif folder == false then
            scrutinizeMissingFolder( c, false )
        elseif errm then
            if errm:sub( 1, 3 ) == "***" then
                app:logV( errm )
            else
                Debug.pause() -- I dont think this is happening.
                app:logE( errm )
            end
        else
            scrutinizeInvalidColl( c )
        end
    end
    function doCollSet( s )
        app:log( "Folder Collection Set being scrutinized: ^1", s:getName() )
        local folder, leaf, errm = self:_getFolder( s )
        if folder then
            scrutinizePair( folder, leaf, s, true )
        elseif folder == false then
            scrutinizeMissingFolder( s, true )
        elseif errm then
            if errm:sub( 1, 3 ) == "***" then
                app:logV( errm )
            else
                Debug.pause() -- I dont think this is happening.
                app:logE( errm )
            end
        else
            scrutinizeInvalidCollSet( s )
        end
    end
    function doColls( fs )
        for i, f in ipairs( fs ) do
            doColl( f )
        end
    end
    function doCollSets( cs )
        for i, f in ipairs( cs ) do
            doCollSet( f )
            doCollSets( f:getChildCollectionSets() )
            doColls( f:getChildCollections() )
            if call:isQuit() then return end
        end
    end
    doFolders( catalog:getFolders() ) -- just builds folder to-do set.
    doCollSets( self.pluginCollSet:getChildCollectionSets() )
    doColls( self.pluginCollSet:getChildCollections() )
    for folder, info in pairs( folderInfo ) do
        if info.checkCount == 0 then
            app:log( "Orphan folder: ^1", folder:getPath() )
        elseif info.checkCount == 1 then
            if info.photoCount == 0 then
                -- good
            elseif info.isLeaf then
                app:logVerbose( "Got leaf ^1 photos: ^2", info.photoCount, folder:getPath() )
            else
                app:logVerbose( "Folder with ^1 photos checked once: ^2", info.photoCount, folder:getPath() )
            end
        elseif info.checkCount == 2 then
            if info.isLeaf then
                if info.photoCount == 0 then
                    app:logWarning( "Leaf sans photos: ^1", folder:getPath() )
                else
                    app:logVerbose( "Leaf checkcount = 2: ^1", folder:getPath() ) -- good
                end
            else
                app:logWarning( "Redundently checked folder: ^1", folder:getPath() )
            end
        else
            app:logWarning( "Overchecked folder: ^1", folder:getPath() )
        end
    end

    app:log()
    app:log( "^1 to scrutinize.", str:plural( nFoldersToScrut, "folder", true ) )    
    app:log( "^1 scrutinized.", str:plural( #scrutSets, "folder collection set", true ) )    
    app:log( "^1 scrutinized.", str:plural( #scrutColls, "folder collection", true ) )    
    app:log( "^1 have missing folders.", str:plural( #setsWithMissingFolders, "folder collection set", true ) )    
    app:log( "^1 have missing folders.", str:plural( #collsWithMissingFolders, "folder collection", true ) )    
    app:log( "^1.", str:plural( #orphSets, "orphan folder collection set", true ) )    
    app:log( "^1.", str:plural( #orphColls, "orphan folder collection", true ) )    
    app:log()
    
end



function FolderCollections:scrutinizeThoroughly()
    app:call( Service:new{ name="Scrutinize Thoroughly", async=true, progress=true, guard=App.guardVocal, main=function( call )
        local s, m = background:pause()
        if s then
            call.scope:setCaption( "Scrutinizing..." )
            cat:initFolderCache() -- scrutinize thoroughly is not initialized as a "run", but does need to get all folders, preferrably quickly.
            self:_scrutinizeThoroughly( call )
        else
            app:logErr( m )
        end
    
    end, finale=function( call )
        background:continue()
    end } )
end



-- Only 1 reasons to convert a collection to a set:
-- 1. subfolders appeared in folder, necessitating 1 or 2 child collections, or set/hierarchy.
-- Note: this function *only* does the conversion. After conversion, the new set will be
-- mirrored in the usual way...
-- Note: it presumably originally had photos in it, or it would not have been a collection, but they may not be there anymore.
-- Calling context must have checked those things, or this function wouldn't be called.
--
-- returns set
function FolderCollections:_convertCollToSet( coll, folder )
    local name = coll:getName()
    local parent = coll:getParent()
    local set
    local s, m = cat:update( 20, "Convert Folder Collection To Set", function( context, phase )
        if phase == 1 then
            coll:removeAllPhotos() -- Dunno if this is strictly necessary, but it's bein' finnicky, so maximizing probability for success seems wise.
            return false
        elseif phase == 2 then
            coll:delete()
            return false
        elseif phase == 3 then
            set = catalog:createCollectionSet( name, parent, false ) -- can't have collection and set of same name, same level, so the way should be clear for new one.
        else
            --Debug.pause( "Catalog update phase out of range", phase )
            app:error( "Catalog update phase out of range: ^1", phase )
        end
    end )
    if s then
        app:log( "Converted to ^1 from collection to set", set:getName() )
        return set
    else
        return nil, m
    end
end



-- Only 1 reason to convert a set to a coll
-- 1. subfolders disappeared...
--
-- returns coll
function FolderCollections:_convertSetToColl( set, folder )
    local name = set:getName()
    local parent = set:getParent()
    local coll
    local s, m = cat:update( 20, "Convert Collection Set To Folder Collection", function( context, phase )
        if phase == 1 then
            set:delete()
            return false
        elseif phase == 2 then
            coll = catalog:createCollection( name, parent, false ) -- can't have collection and set of same name, same level, so the way should be clear for new one.
        else
            --Debug.pause( "Catalog update phase out of range:", phase )
            app:error( "Catalog update phase out of range: ^1", phase )
        end
    end )
    if s then
        app:log( "Converted ^1 from set to collection.", coll:getName() )
        return coll
    else
        return nil, m
    end
end




-- for specified (pre-certified) folder collection source, which may be collection or set.
function FolderCollections:_mirrorStacks( rebuild, collOrSet, service )
    local nNoSels = 0
    local nStacked = 0
    local nToStack = 0
    local viewFilter
    local status, message =
    app:call( Call:new{ name="Mirror Stack Source", main=function( icall )
        if service and service.scope then
            service.scope:setCaption( "Mirroring stacks in " .. collOrSet:getName() )
        end
        local s, m = gui:gridMode( true ) -- mandatory.
        if s then
            app:logv( "switch to grid mode was successful" )
        else
            service:abort( m )
            return
        end
        local function mirrorColl( folder, coll )
            if self.collsVisited[coll] then
                app:logVerbose( "*** Collection already visited, not mirroring stacks in collection: ^1, folder: ^2", coll:getName(), folder:getName() )
                return
            else
                app:log( "Mirroring stacks in collection: ^1, folder: ^2", coll:getName(), folder:getName() )
                self.collsVisited[coll] = true
            end
    
            local function prep()
                catalog:setActiveSources{ coll }
                LrTasks.sleep( .05 ) -- does this and the above work reliably? - so far so good...
                if rebuild then        
                    local keys = "{Ctrl Down}a{Ctrl Up}" -- select all.
                    local s, m = app:sendWinAhkKeys( keys, .05 ) -- ###1 mac
                    if s then
                        keys = "{Alt Down}p{Alt Up}au" -- photo -> stacking -> unstack.
                        s, m = app:sendWinAhkKeys( keys, .05 ) -- ###1 mac
                    end
                    if s then
                        app:logVerbose( "ready to rebuild stacks in coll" )
                        return true
                    else
                        app:logErr( m )
                    end
                else
                    local keys = "{Ctrl Down}a{Ctrl Up}" -- select all.
                    local s, m = app:sendWinAhkKeys( keys, .05 ) -- ###1 mac
                    if s then
                        keys = "{Alt Down}p{Alt Up}ac" -- photo -> stacking -> collapse all stacks.
                        s, m = app:sendWinAhkKeys( keys, .05 ) -- ###1 mac
                    end
                    if s then
                        app:logVerbose( "ready to update stacks in coll" )
                        return true
                    else
                        app:logErr( m )                                
                    end
                end
            end
                        
            local stacks = {} -- keyed by masterPhoto, contains an array of bottom feeders.
            local photos = folder:getPhotos( false )
            if photos == nil then
                if folder:getChildren() == nil then
                    Debug.pause()
                    app:logV( "*** Bug in Lightroom - if Lr mobile folder, it's already been logged, if not: do tell..", folder:getPath() or "Lr not giving path - ugh" )
                    return
                else
                    app:logE( "A folder has probably been renamed recently (current name is '^1'). Due to a bug in Lightroom, you may need to restart Lightroom to clear this condition.", folder:getName() or "Lr not giving name~" )
                    return
                end
            end
            local rawMeta = cat:getBatchRawMetadata( photos, { 'isInStackInFolder', 'stackPositionInFolder', 'topOfStackInFolderContainingPhoto' } )
            
            for i, photo in ipairs( photos ) do
                if rawMeta[photo]['isInStackInFolder'] then
                    local stackPos = num:numberFromString( rawMeta[photo]['stackPositionInFolder'] ) -- robust handler, me-thinks.
                    if stackPos ~= nil then -- got number.
                        if stackPos == 1 then
                            if stacks[photo] then
                                -- Debug.pause()
                            else
                                stacks[photo] = { photo }
                            end
                        else
                            local parentPhoto = rawMeta[photo]['topOfStackInFolderContainingPhoto']
                            if parentPhoto then
                                if stacks[parentPhoto] then
                                    local a = stacks[parentPhoto]
                                    a[#a + 1] = photo
                                else
                                    stacks[parentPhoto] = { parentPhoto, photo }
                                end
                            else
                                -- bad?
                            end
                        end
                    else
                        -- bad                            
                    end
                else
                    -- not in stack.
                end
            end
            local count = tab:countItems( stacks )
            if count > 0 then
                local prepped = prep()
                if prepped then
                    app:log("Prepped ^1 for ^2", coll:getName(), str:plural( count, "item", true )  )
                else
                    -- error already logged.
                    return
                end
                for masterPhoto, photos in pairs( stacks ) do
                    if #photos > 1 then
                        nToStack = nToStack + 1
                        app:log( "Mirroring stack, master: ^1, total in stack: ^2", masterPhoto:getFormattedMetadata( 'fileName' ), #photos  )
                        local s, m = cat:setSelectedPhotos( masterPhoto, photos ) -- not perfect, since excuse may be stackage in source folder, yet they're being selected in a collection!
                        if s then
                            app:log( "Selected" )
                            if WIN_ENV then
                                local keys = "{Alt Down}p{Alt Up}ag" -- other languages? ###1 - documented anyway, but should be configurable.
                                local s, m = app:sendWinAhkKeys( keys, .1 ) -- without sleep (yield is not enough) this only gets 90%. So far with .1, I get 100%.
                                if s then
                                    app:log( "Stacked" )
                                    nStacked = nStacked + 1
                                else
                                    app:logErr( m )
                                end
                            else
                                app:logErr( "Mirroring stacks not supported on Mac, yet." )
                            end
                        elseif rebuild then
                            nNoSels = nNoSels + 1
                            app:logError( "No can select photos in stack." ) -- error message is probably bogus @1/Jun/2012 3:01
                        else
                            nNoSels = nNoSels + 1
                            app:log( "*** No can select - ignoring stack (it may be collapsed(?))." ) -- error message is probably bogus @1/Jun/2012 3:01
                        end
                    else
                        -- ?
                    end    
                end
            else
                app:log( "No stacks." )
            end
        end
        
        local mirrorColls, mirrorCollSets, mirrorCollSet -- stack-wise
        function mirrorColls( colls )
            for i, c in ipairs( colls ) do
                local folder, leaf, errm = self:_getFolder( c )
                if folder then
                    mirrorColl( folder, c )
                elseif folder == false then -- gone
                    self:_deleteItem( c )
                elseif errm then
                    if errm:sub( 1, 3 ) == "***" then
                        app:logV( errm )
                    else
                        Debug.pause() -- I dont think this is happening.
                        app:logE( errm )
                    end
                else
                    app:logWarning( "Folder collection has no valid folder counterpart." ) -- ?
                end
                if service:isQuit() then return end
            end
        end
        function mirrorCollSets( css )
            for i, cs in ipairs( css ) do
                mirrorCollSet( cs )
                if service:isQuit() then return end
            end
        end
        function mirrorCollSet( cs )
            mirrorCollSets( cs:getChildCollectionSets() )
            mirrorColls( cs:getChildCollections() )
        end
        if not app:getPref( 'assumeGlobalLibFilter' ) then
            viewFilter = catalog:getCurrentViewFilter()        
            cat:clearViewFilter()
        -- else do externally.
        end
        local folder, leaf, errm = self:_getFolder( collOrSet )
        local collOrSetType = cat:getSourceType( collOrSet )
        if collOrSetType == 'LrCollection' then
            mirrorColl( folder, collOrSet )
        elseif collOrSetType == 'LrCollectionSet' then
            mirrorCollSet( collOrSet )
        elseif errm then
            if errm:sub( 1, 3 ) == "***" then
                app:logV( errm )
            else
                Debug.pause() -- I dont think this is happening.
                app:logE( errm )
            end
        else
            app:error( "Program failure" )
        end
    end, finale=function( icall )
        self.nNoSels = nNoSels
        self.nStacked = nStacked
        self.nToStack = nToStack
        if viewFilter then
            catalog:setViewFilter( viewFilter )
        end
    end } )
    return status, message -- synchronous call.
end



--- Mirror folder stacks in folder collections.
--
--  @param  params (table) members:
--    <br>    title (string) operation title: 'Rebuild Stacks', or 'Update Stacks' - must be one of these: verbatim.
--
--  @usage  Originally designed for use as button handler, but that does not work when invoked via persistent dialog box like plugin manager,
--    <br>  due to incompatibility with AutoHotkey. Presently serving file menu functions instead.
--
--  @usage  @2/Jun/2012 0:03, recurses folder collection sets.
--    <br>  Stack mirroring works different than some other functions because:
--    <br>  Stacks don't work in collection sets view. Thus stacking is targeted at folder collections only.
--    <br>  So the objective is to let user select sources for stack sync. The reason auto (background) stack sync is not implemented is:
--    <br>  There is no way to tell what collection stacks are set at, so they would constantly need to be redone to assure - no way to do it and still
--    <br>  allow user to get any work done (since also requires altering selection...). I am however entertaining the notion of auto-stack upon startup,
--    <br>  since that would afford the opportunity to establish a 100% sync upon startup before user really needs selection control...
--
function FolderCollections:mirrorStacks( params )
    local rebuild
    local selPhotosEtc
    app:call( Service:new{ name=params.title, async=true, progress=true, main=function( call )
        if MAC_ENV then
            call.scope:setCaption( str:fmt( "^1 dialog needs your attention...", app:getAppName() ) )
            app:show{ warning="Sorry - Stack mirroring is not yet supported on Mac, do standby..." }
            call:cancel()
            return
        end
        if call.name == "Rebuild Stacks" then
            rebuild = true
        elseif call.name == "Update Stacks" then
            rebuild = false
        else
            app:error( "Program failure." )
        end
        local s, m = background:pause()
        if s then

            self:_initRun() -- don't do this before pausing, otherwise background task will want to delete collections/sets.
            
            local toMirror = {}
            for i, coll in ipairs( catalog:getActiveSources() ) do -- may include children and their parents, redundently. - oh well, not sure I want to try to sort that out at this point,
                -- user can control: don't select same source in more than one fashion: Note: I will make sure to keep a set of done collections to not repeat in gut method above.
                local folder, leaf, errm = self:_getFolder( coll )
                if folder then
                    toMirror[#toMirror + 1] = { folder, coll }
                    -- mirror( folder, coll )
                elseif folder == false then
                    toMirror = nil
                    app:logErr( "Need to rebuild or update folders first." )
                    break
                elseif errm then
                    if errm:sub( 1, 3 ) == "***" then
                        app:logV( errm )
                    else
                        Debug.pause() -- I dont think this is happening.
                        app:logE( errm )
                    end
                else
                    toMirror = nil
                    app:logErr( "Only folder collections and sets should be selected." )
                    break
                end
            end
            if toMirror then
                if #toMirror > 0 then
                    app:log( "To mirror: ^1", #toMirror )
                    local answer
                    call.scope:setCaption( str:fmt( "^1 dialog needs your attention...", app:getAppName() ) )
                    if rebuild then
                        answer = app:show{ confirm="Rebuild stacks? - this will unstack all stacks in active folder collection sources, then restack so all will match corresponding folders.\n \n*** Do not remove focus from Lightroom while operation is in progress (e.g. do not select another application window).\n \n***Also, if dialog boxes pop up in Lightroom while it's in progress, you'll need to retry the rebuild.",
                            buttons = { dia:btn( "OK", 'ok' ) },
                        }
                    else
                        answer = app:show{ confirm="Update stacks? - this will collapse all stacks in active folder collection sources, and ignore collapsed stacks, stacking only new stacks (collapsed/ignored stacks may no longer match corresponding folder - consider rebuilding stacks instead: update is not much faster than rebuild, it just makes sure no existing stacks in folder collections are disturbed).\n \n*** Do not remove focus from Lightroom while operation is in progress (e.g. do not select another application window).\n \n***Also, if dialog boxes pop up in Lightroom while it's in progress, you'll need to retry the update.",
                            buttons = { dia:btn( "OK", 'ok' ) },
                        }
                    end
                    if answer == 'ok' then
                        selPhotosEtc = cat:saveSelPhotos()
                        if app:getPref( 'assumeGlobalLibFilter' ) then
                            cat:clearViewFilter()
                        end
                        for i, item in ipairs( toMirror ) do
                            -- local folder = item[1] - only used for initial assessment...
                            local collOrSet = item[2]
                            local s, m = self:_mirrorStacks( rebuild, collOrSet, call ) -- source is guaranteed to be folder collection, or folder collection set.
                            if s then
                                -- already logged.
                            else
                                app:logErr( "Unable to mirror source stacks: ^1 - error message: ^2", collOrSet:getName(), m )
                            end
                        end
                    else -- dialog box will shortenly be taken over by default handling.
                        call:cancel()
                        return
                    end
                else
                    app:show{ warning="No sources to mirror." }
                    call:cancel()
                    return
                end
            else
                -- see log file.
                call:abort( "Invalid source selected." )
            end
        else
            app:show{ warning="Unable to pause background task." }
            call:cancel()
            return
        end
    end, finale=function( call )
        background:continue()
        if rebuild == nil then return end -- since it means error very early on...
        
        cat:restoreSelPhotos( selPhotosEtc ) -- includes view filter.
        
        if call.status and not call:isCanceled() and not call:isAborted() then
            -- Note: there is potential for race accessing stats used for mirroring which could get re-init by background task,###1
            app:log()
            app:log( "^1 to stack", self.nToStack )
            app:log( "^1 stacked", self.nStacked )
            app:log( "^1 no selects (presumably already stacked)", self.nNoSels )
            app:log()
            if rebuild then
                if self.nToStack == self.nStacked then
                    if self.nNoSels == 0 then
                        app:show{ info="All ^1 rebuilt.", self.nToStack }
                    else
                        app:show{ warning="^1/^2 stacks built, but ^3 \"no selects\"", self.nToStack, self.nToStack, self.nNoSels }
                    end
                else
                    app:show{ warning="Of ^1 to stack, ^2 stacked, ^3 \"no selects\"", self.nToStack, self.nStacked, self.nNoSels }
                end
            else
                if self.nToStack == self.nNoSels then
                    app:show{ info="All stacks appear to have been already up to date." }
                else
                    app:show{ info="Updated ^1/^2 stacks, ^3 already stacked.", self.nStacked, self.nToStack, self.nNoSels }
                end
            end
        -- else let default handling prevail.
        end
    end } )
end




-- 'Report' function, called from plugin manager, to compare photos in folders, to photos in folder collections.
-- @25/May/2012 21:51, simply compares catalog photo count to sum of all photos in folder collections.
function FolderCollections:report( button )
    app:call( Call:new{ name=button.title, async=true, guard=App.guardVocal, main=function( call )
    
        local s, m = background:pause()
        if s then
            -- paused
        else
            app:show{ error="Unable to pause background task - " .. str:to( m ) }
            call:cancel()
            return
        end

        call.scope = LrDialogs.showModalProgressDialog {
            title = str:fmt( "^1 Report", app:getAppName() ),
            caption = "Please wait...",
            functionContext = call.context,
        }
        
        local report = self:_integrityCheck( call )
        if call:isQuit() then return end
    
        local nPhotos = report.nPhotosInFolders
        local nPhotos2 = report.nPhotosInFolderCollections
        local diff = report.nTotalPhotosShy -- if negative, then there are more photos in folder collections than folders.
       
        if diff > 0 then
            app:show{ info="Of ^1 photos in catalog, ^2 are being represented in folder collections (difference=^3). If 'Update Folder Collections' does not eliminate the difference, there is some kind of anomaly (possibly insignificant) in your catalog or this plugin.", nPhotos, nPhotos2, diff }
        elseif diff < 0 then
            diff = -diff
            app:show{ info="Of ^1 photos in folder collections, ^2 are in catalog (difference=^3). If 'Update Folder Collections' does not eliminate the difference, there is some kind of anomaly (possibly insignificant) in your catalog or this plugin.", nPhotos2, nPhotos, diff }
        else
            app:show{ info="All ^1 photos in catalog are represented in folder collections - that's a good thing :-)", nPhotos }
        end
    
    end, finale=function( call )
        background:continue()
    end } )
end



-- Make sure this is called before background task is continued, so there is not a race accessing stat vars.
function FolderCollections:logStats()
    if not self.initForRun then return end -- problem occurred before run was init'd.
    app:log()
    app:log( "^1 added.", str:plural( self.nAdds, "photo", 1 ) )
    app:log( "^1 removed.", str:plural( self.nRmvs, "photo", 1 ) )
    app:log( "^1 deleted.", str:plural( self.nCollsDel, "folder collection", 1 ) )
    app:log( "^1 deleted.", str:plural( self.nSetsDel, "folder collection set", 1 ) )
    app:log()
    self.initForRun = false -- assures no logging of stats from previous run.
end



-- called by background task, source is whatever is selected.
-- not a "pure" mirror/cleanup-delete, since it has stipulations concerning leaf-only, and prompt before deletion (since user will be viewing
-- selected source).
function FolderCollections:processSource( source )
    local sourceIsLeaf
    local sourceType = cat:getSourceType( source )
    if sourceType == 'LrCollection' then
        sourceIsLeaf = true
    elseif sourceType == 'LrCollectionSet' then
        -- not
    else
        return -- sync does not apply.
    end
    local folder, leaf, errm = self:_getFolder( source, true ) -- bypass the cache when background task - no good way has been invented yet to keep it fresh (reminder: only affects unmapped network folders) ###2.
    if folder then
        if app:getPref( 'leafOnly' ) then
            local children = folder:getChildren()
            if children == nil then Debug.pause(); return end -- I don't think this will happen (?)
            local folderIsLeaf = ( #children == 0 )
            if not sourceIsLeaf and not folderIsLeaf then -- neither is a leaf.
                return
            -- else continue if source is leaf or folder is leaf, even if source is not, since synchronization is essential when both are leaves, or if there's a mismatch (in which case a type conversion needs to be done).
            end
        end
        
        if not self.initForRun then -- user has run a service since last background processing, or an error occurred before init'd...
            self:_initRun( nil, true ) -- this will kill service member object, is that ok? ###1. Also, do not init folder cache - it's being bypassed in background process.
            return -- that's all for this pass - next time do the rest...
        elseif self.recomputeRootsHoldoffCounter == nil or self.recomputeRootsHoldoffCounter > 20 then
            self:_computeRoots() -- In case user has added folder, e.g. through importing, which could affect auto-sync, by virtue of a new root.
            self.recomputeRootsHoldoffCounter = 0
            return -- that's all for this pass - next time do the rest...
        else
            self.recomputeRootsHoldoffCounter = self.recomputeRootsHoldoffCounter + 1
        end
            
        local newSource = self:_mirrorFolder( folder, source, leaf )
        if newSource then
            catalog:setActiveSources{ newSource }
        end
    elseif folder == false then -- missing lr-folder
        local answer
        if not leaf then
            app:logVerbose( "No folder corresponding to '^1'", source:getName() )
            answer = app:show{ confirm="Source folder no longer exists - ok to remove collection or set: '^1'?",
                subs = source:getName(),
                actionPrefKey = "Remove selected folder collection or set",
                -- no buttons means only cancel is 'X'.
            }
        else
            app:logVerbose( "Folder corresponding to '^1' no longer warrants leaf collection.", source:getName() )
            answer = app:show{ confirm="Source folder no longer warrants leaf collection - ok to remove collection or set: '^1'?",
                subs = source:getName(),
                actionPrefKey = "Remove selected folder collection or set", -- same key as above.
                -- no buttons means only cancel is 'X'.
            }
        end
        if answer == 'ok' then
            local parent = source:getParent()
            local deleted = self:_deleteItem( source )
            if deleted then
                if parent then
                    catalog:setActiveSources{ parent }
                end
            -- else - not sure what to do in this case.
            end
        else
            app:logVerbose( "Folder collection removal canceled by user." )
            app:sleep( 1 ) -- he/she will probably be re-prompted until moving off source or disabling plugin...
        end
    elseif errm then
        if errm:sub( 1, 3 ) == "***" then
            app:logV( errm )
        else
            Debug.pause() -- I dont think this is happening.
            app:logE( errm )
        end
    -- else not a folder collection.
    end
end



return FolderCollections