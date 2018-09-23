--[[
        ExtendedBackground.lua
--]]

local ExtendedBackground, dbg, dbgf = Background:newClass{ className = 'ExtendedBackground' }



--- Constructor for extending class.
--
--  @usage      Although theoretically possible to have more than one background task,
--              <br>its never been tested, and its recommended to just use different intervals
--              <br>for different background activities if need be.
--
function ExtendedBackground:newClass( t )
    return Background.newClass( self, t )
end



--- Constructor for new instance.
--
--  @usage      Although theoretically possible to have more than one background task,
--              <br>its never been tested, and its recommended to just use different intervals
--              <br>for different background activities if need be.
--
function ExtendedBackground:new( t )
    local interval
    local minInitTime
    local idleThreshold
    if app:getUserName() == '_RobCole_' and app:isAdvDbgEna() then
        interval = .1
        idleThreshold = 1
        minInitTime = 3
    else
        interval = .5
        idleThreshold = 2 -- (every other cycle) appx 1/sec.
        minInitTime = 30 -- default min-init-time is 10-15 seconds or so.
    end    
    local o = Background.new( self, { interval=interval, minInitTime=minInitTime, idleThreshold=idleThreshold } )
    return o
end



--- Initialize background task.
--
--  @param      call object - usually not needed, but its got the name, and context... just in case.
--
function ExtendedBackground:init( call )
    -- Note: although for some reason this does not show upon startup until opening plugin manager (ugh), it's still better than nothing
    -- it sucks if ya disable a plugin and it still goes through the lengthy init (only way to truly disable in that case is to remove).
    if app:isPluginEnabled() then
        app:logV( "Initialization of background task proceding, since plugin enabled.." )
    else
        app:logW( "Unable to initialize because plugin is disabled - background processing will terminate. After enabling plugin, reload it (or restart Lightroom)." )
        self.initStatus = true -- I think I prefer to not make a big stink if disabled.
        self:quit() -- I guess..
        --app:show( { error="Unable to initialize - plugin is disabled." } ) -- note: this doesn't show upon startup, until opening plugin manager - ya know...
        return
    end
    local s, m = LrTasks.pcall( folderCollections.init, folderCollections, call )
    if s then    
        self.initStatus = not call:isAborted() -- Note: it's user's perogative to cancel stack mirroring without penalty.
        -- this pref name is not assured nor sacred - modify at will.
        if not app:getPref( 'background' ) then
            app:logv( "Finished with async init since continued background processing is not enabled." )
            self:quit() -- indicate to base class that background processing should not continue past init.
            return
        end
        if not self.initStatus then -- check preference that determines if background task should start.
            app:logv( "Background task not continuing since startup was aborted." )
            self:quit() -- indicate to base class that background processing should not continue past init.
        end
    else
        self.initStatus = false -- ###1 quit?
        app:logError( "Unable to initialize due to error: " .. str:to( m ) )
        app:show( { error="Unable to initialize." } )
    end
end



--- Background processing method.
--
--  @param      call object - usually not needed, but its got the name, and context... just in case.
--
function ExtendedBackground:process( call )
    local sources = catalog:getActiveSources()
    for i, source in ipairs( sources ) do
        folderCollections:processSource( source )
    end
end
    


return ExtendedBackground
