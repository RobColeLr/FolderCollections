--[[
        ExtendedManager.lua
--]]


local ExtendedManager, dbg, dbgf = Manager:newClass{ className='ExtendedManager' }



--[[
        Constructor for extending class.
--]]
function ExtendedManager:newClass( t )
    return Manager.newClass( self, t )
end



--[[
        Constructor for new instance object.
--]]
function ExtendedManager:new( t )
    return Manager.new( self, t )
end



--- Initialize global preferences.
--
function ExtendedManager:_initGlobalPrefs()
    -- Instructions: delete the following line (or set property to nil) if this isn't an export plugin.
    --fprops:setPropertyForPlugin( _PLUGIN, 'exportMgmtVer', "2" ) -- a little add-on here to support export management. '1' is legacy (rc-common-modules) mgmt.
    -- Instructions: uncomment to support these external apps in global prefs, otherwise delete:
    -- app:initGlobalPref( 'exifToolApp', "" )
    -- app:initGlobalPref( 'mogrifyApp', "" )
    -- app:initGlobalPref( 'sqliteApp', "" )
    Manager._initGlobalPrefs( self )
end



--- Initialize local preferences for preset.
--
function ExtendedManager:_initPrefs( presetName )
    -- Instructions: uncomment to support these external apps in global prefs, otherwise delete:
    -- app:initPref( 'exifToolApp', "", presetName )
    -- app:initPref( 'mogrifyApp', "", presetName )
    -- app:initPref( 'sqliteApp', "", presetName )
    -- *** Instructions: delete this line if no async init or continued background processing:
    app:initPref( 'background', true, presetName ) -- true to support on-going background processing, after async init (auto-update most-sel photo).
    --
    app:initPref( 'leafOnly', true, presetName ) -- auto-sync pref.
    -- app:initPref( 'rebuildStacksUponStartup', false ) - @1/Jun/2012 21:59 implemented as "advanced" option.
    --
    Manager._initPrefs( self, presetName )
end



--- Start of plugin manager dialog.
-- 
function ExtendedManager:startDialogMethod( props )
    -- *** Instructions: uncomment if you use these apps and their exe is bound to ordinary property table (not prefs).
    Manager.startDialogMethod( self, props ) -- adds observer to all props.
end



--- Preference change handler.
--
--  @usage      Handles preference changes.
--              <br>Preferences not handled are forwarded to base class handler.
--  @usage      Handles changes that occur for any reason, one of which is user entered value when property bound to preference,
--              <br>another is preference set programmatically - recursion guarding is essential.
--
function ExtendedManager:prefChangeHandlerMethod( _id, _prefs, key, value )
    Manager.prefChangeHandlerMethod( self, _id, _prefs, key, value )
end



--- Property change handler.
--
--  @usage      Properties handled by this method, are either temporary, or
--              should be tied to named setting preferences.
--
function ExtendedManager:propChangeHandlerMethod( props, name, value, call )
    if app.prefMgr and (app:getPref( name ) == value) then -- eliminate redundent calls.
        -- Note: in managed cased, raw-pref-key is always different than name.
        -- Note: if preferences are not managed, then depending on binding,
        -- app-get-pref may equal value immediately even before calling this method, in which case
        -- we must fall through to process changes.
        return
    end
    -- *** Instructions: strip this if not using background processing:
    if name == 'background' then
        app:setPref( 'background', value )
        if value then
            local started = background:start()
            if started then
                app:show( "Auto-processing started." )
            else
                app:show( "Auto-processing already started." )
            end
        elseif value ~= nil then
            app:call( Call:new{ name = 'Stop Background Task', async=true, guard=App.guardVocal, main=function( call )
                local stopped
                repeat
                    stopped = background:stop( 10 ) -- give it some seconds.
                    if stopped then
                        app:logVerbose( "Auto-processing was stopped by user." )
                        app:show( "Auto-processing is stopped." ) -- visible status wshould be sufficient.
                    else
                        if dialog:isOk( "Auto-processing stoppage not confirmed - try again? (auto-processing should have stopped - please report problem; if you cant get it to stop, try reloading plugin)" ) then
                            -- ok
                        else
                            break
                        end
                    end
                until stopped
            end } )
        end
    elseif name == 'leafOnly' then
        local answer = 'ok'
        if value == false then
            LrTasks.startAsyncTask( function()
                local answer = app:show{ confirm="Are you sure? If so, remember to be careful to only select folder collection sets that you want to be continually synchronized with source folder.",
                    buttons = { dia:btn( "Yes", 'ok' ), dia:btn( "No", 'cancel' ) },
                }
                if answer == 'cancel' then
                    props[name] = true -- will result in a change handling which sets pref.
                end
            end )
        end
        if answer == 'ok' then
            app:setPref( name, value )
        end
    else
        -- Note: preference key is different than name.
        Manager.propChangeHandlerMethod( self, props, name, value, call )
    end
end



--- Sections for bottom of plugin manager dialog.
-- 
function ExtendedManager:sectionsForBottomOfDialogMethod( vf, props)

    local appSection = {}
    if app.prefMgr then
        appSection.bind_to_object = props
    else
        appSection.bind_to_object = prefs
    end
    
	appSection.title = app:getAppName() .. " Settings"
	appSection.synopsis = bind{ key='presetName', object=prefs }

	appSection.spacing = vf:label_spacing()
	
	if gbl:getValue( 'background' ) then
	
	    -- *** Instructions: tweak labels and titles and spacing and provide tooltips, delete unsupported background items,
	    --                   or delete this whole clause if never to support background processing...
	    -- PS - One day, this may be handled as a conditional option in plugin generator.
	
        appSection[#appSection + 1] =
            vf:row {
                bind_to_object = props,
                vf:static_text {
                    title = "Auto-mirror control",
                    width = share 'label_width',
                },
                vf:checkbox {
                    title = "Automatically update contents of selected folder collection.",
                    value = bind( 'background' ),
    				--tooltip = "",
                    width = share 'data_width',
                },
            }
        appSection[#appSection + 1] =
            vf:row {
                bind_to_object = props,
                vf:static_text {
                    title = "Auto-mirror folder collection sets",
                    width = share 'label_width',
                },
                vf:checkbox {
                    title = "If unchecked, only folder collections with photos will be auto-synchronized.",
                    value = LrBinding.negativeOfKey( 'leafOnly' ),
                    enabled = bind( 'background' ),
                    width = share 'data_width',
                },
            }
        appSection[#appSection + 1] =
            vf:row {
                vf:static_text {
                    title = "Auto-mirror status",
                    width = share 'label_width',
                },
                vf:edit_field {
                    bind_to_object = prefs,
                    value = app:getGlobalPrefBinding( 'backgroundState' ),
                    width = share 'data_width',
                    tooltip = 'auto-check status',
                    enabled = false, -- disabled fields can't have tooltips.
                },
            }
    end

    appSection[#appSection + 1] = vf:spacer{ height=5 }
    appSection[#appSection + 1] =
        vf:row {
            vf:push_button {
                title = "Rebuild Folder Collections",
                width = share 'label_width',
                action = function( button )
                    folderCollections:build(true)
                end,
                tooltip = "Usually not necessary, but if you got something weird going on that isn't being set straight by doing an update...",
            },
            vf:static_text {
                title = "Re-build entire folder collection set by deleting and recreating.",
            },
        }
    appSection[#appSection + 1] =
        vf:row {
            vf:push_button {
                title = "Update Folder Collections",
                width = share 'label_width',
                action = function( button )
                    folderCollections:build()
                end,
                tooltip = "Use this if you've done a bunch of folder restructuring, so changes are reflected in folder collection tree.",
            },
            vf:static_text {
                title = "Update entire folder collection set by synchronizing root sources.",
            },
        }
    if app:getUserName() == "_RobCole_" or app:isAdvDbgEna() then
    
        -- Replication of file menu functions.
    
        appSection[#appSection + 1] =
            vf:row {
                vf:push_button {
                    title = "Sync Selected Sources",
                    width = share 'label_width',
                    action = function( button )
                        folderCollections:syncSelected()
                    end,
                },
                vf:static_text {
                    title = "Synchronize selected folder collections/sets with corresponding folders.",
                },
            }
        appSection[#appSection + 1] =
            vf:row {
                vf:push_button {
                    title = "Go To Folders",
                    width = share 'label_width',
                    action = function( button )
                        folderCollections:goToFolders()
                    end,
                },
                vf:static_text {
                    title = "Select folders corresponding to folder collections/sets.",
                },
            }
    end
    appSection[#appSection + 1] =
        vf:row {
            vf:push_button {
                title = "Report",
                width = share 'label_width',
                action = function( button )
                    folderCollections:scrutinizeThoroughly()
                end,
            },
            vf:static_text {
                title = "Thoroughly scrutinize folders and folder collections/sets and log details.",
            },
        }

    if not app:isRelease() then
    	appSection[#appSection + 1] = vf:spacer{ height = 20 }
    	appSection[#appSection + 1] = vf:static_text{ title = 'For plugin author only below this line:' }
    	appSection[#appSection + 1] = vf:separator{ fill_horizontal = 1 }
    	appSection[#appSection + 1] = 
    		vf:row {
    			vf:edit_field {
    				value = bind( "testData" ),
    			},
    			vf:static_text {
    				title = str:format( "Test data" ),
    			},
    		}
    	appSection[#appSection + 1] = 
    		vf:row {
    			vf:push_button {
    				title = "Test",
    				action = function( button )
    				    app:call( Call:new{ name='Test', async=true, guard=App.guardVocal, main=function( call )
                            --app:show( { info="^1: ^2" }, str:to( app:getGlobalPref( 'presetName' ) or 'Default' ), app:getPref( 'testData' ) )
                            -- folderCollections:report()
                            --folderCollections:scrutinizeThoroughly()
                        end } )
    				end
    			},
    			vf:static_text {
    				title = str:format( "Perform tests." ),
    			},
    		}
    end
		
    local sections = Manager.sectionsForBottomOfDialogMethod ( self, vf, props ) -- fetch base manager sections.
    if #appSection > 0 then
        tab:appendArray( sections, { appSection } ) -- put app-specific prefs after.
    end
    return sections
end



return ExtendedManager
-- the end.