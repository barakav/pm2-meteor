fs = require 'fs'
{exec} = require 'child_process'
path = require 'path'
nodemiral = require 'nodemiral'
url = require 'url'
abs = require 'abs'
_settings = require './settings'
CWD = process.cwd()

isGitProject = (pm2mConf)->
  if !pm2mConf.appLocation.local or pm2mConf.appLocation.local.trim() is ""
    return true
  else
    return false

reapplyMeteorSettings = (pm2mConf)->
  if isGitProject pm2mConf
    if pm2mConf.meteorSettingsLocation and pm2mConf.meteorSettingsLocation isnt ""
      meteorSettingsObj = {}
      meteorSettingsLocation = path.join CWD, _settings.gitDirName, pm2mConf.meteorSettingsLocation
      pm2EnvLocation = path.join CWD, _settings.pm2EnvConfigName
      meteorSettingsObj = require meteorSettingsLocation
      pm2EnvObj = require pm2EnvLocation
      pm2EnvObj.apps[0].env["METEOR_SETTINGS"] = meteorSettingsObj
      prettyJson = JSON.stringify(pm2EnvObj, null, 2)
      try
        fs.writeFileSync _settings.pm2EnvConfigName, prettyJson
      catch err
        console.log "Couldn't update #{_settings.pm2EnvConfigName} with Meteor Settings"
        console.log err.message
        process.exit 1


# Local tasks
module.exports =
  initPM2MeteorSettings: (done)->
    json = _settings.pm2MeteorConfigTemplate
    prettyJson = JSON.stringify(json, null, 2)
    try
      fs.writeFileSync _settings.pm2MeteorConfigName, prettyJson
    catch err
      done err
    done()

  generatePM2EnvironmentSettings: (pm2mConf, done)->
    envJson = _settings.pm2EnvConfigTemplate
    appJson = {}
    # Fill appJson
    appJson.name = pm2mConf.appName
    appJson.env = pm2mConf.env
    appJson.script = path.join(pm2mConf.server.deploymentDir, pm2mConf.appName, "bundle/main.js")
    appJson.exec_mode = pm2mConf.server.exec_mode
    appJson.instances = pm2mConf.server.instances
    # get Meteor settings
    meteorSettingsObj = {}
    unless isGitProject pm2mConf
      if pm2mConf.meteorSettingsLocation
        try
          meteorSettingsLocation = abs(pm2mConf.meteorSettingsLocation)
          meteorSettingsObj = JSON.parse(fs.readFileSync meteorSettingsLocation, 'utf8')
        catch err
          done err
    appJson.env["METEOR_SETTINGS"] = meteorSettingsObj
    envJson.apps.push appJson
    prettyJson = JSON.stringify(envJson, null, 2)
    try
      fs.writeFileSync _settings.pm2EnvConfigName, prettyJson
    catch err
      done message: "#{err.message}"
    done()

  bundleApplication: (pm2mConf, done)->
    exec "cd #{abs(pm2mConf.appLocation.local)} && meteor build #{pm2mConf.meteorBuildFlags} --directory #{CWD}", (err, stdout, stderr)->
      if err
        done err
      else
        exec "cd #{CWD} && tar -zcvf #{_settings.bundleTarName} #{_settings.bundleName} #{_settings.pm2EnvConfigName}", {maxBuffer: 1024*200000}, (err, stdout, stderr)->
          if err
            done err
          else
            done()
  bundleApplicationFromGit: (pm2mConf, done)->
    exec "cd #{CWD} && git clone #{pm2mConf.appLocation.git} --branch #{pm2mConf.appLocation.branch} #{_settings.gitDirName}", (err, stdout, stderr)->
      if err
        done err
      else
        reapplyMeteorSettings pm2mConf
        exec "cd #{path.join CWD, _settings.gitDirName} && meteor build #{pm2mConf.meteorBuildFlags} --directory #{CWD}", (err, sdout, stderr)->
          if err
            done err
          else
            exec "cd #{CWD} && tar -zcvf #{_settings.bundleTarName} #{_settings.bundleName} #{_settings.pm2EnvConfigName}", {maxBuffer: 1024*200000}, (err, stdout, stderr)->
              if err
                done err
              else
                done()
  makeClean: (done)->
    exec "cd #{CWD} && rm -rf #{_settings.bundleName} && rm #{_settings.pm2EnvConfigName} && rm #{_settings.bundleTarName} && rm -rf #{_settings.gitDirName}", (err, stdout, stderr)->
      if err
        done err
      else
        done()
