/*
This file is part of the GhostDriver by Ivan De Marino <http://ivandemarino.me>.

Copyright (c) 2012-2014, Ivan De Marino <http://ivandemarino.me>
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

var ghostdriver = ghostdriver || {};

ghostdriver.Session = function(desiredCapabilities) {
    // private:
    const
    _const = {
        TIMEOUT_NAMES       : {
            SCRIPT              : "script",
            IMPLICIT            : "implicit",
            PAGE_LOAD           : "page load"
        },
        ONE_SHOT_POSTFIX    : "OneShot",
        LOG_TYPES           : {
            HAR                 : "har",
            BROWSER             : "browser"
        },
        PROXY_TYPES         : {
            MANUAL              : "manual",
            DIRECT              : "direct"
        }
    };

    var
    _defaultCapabilities = {    // TODO - Actually try to match the "desiredCapabilities" instead of ignoring them
        "browserName" : "phantomjs",
        "version" : phantom.version.major + '.' + phantom.version.minor + '.' + phantom.version.patch,
        "driverName" : "ghostdriver",
        "driverVersion" : ghostdriver.version,
        "platform" : ghostdriver.system.os.name + '-' + ghostdriver.system.os.version + '-' + ghostdriver.system.os.architecture,
        "javascriptEnabled" : true,
        "takesScreenshot" : true,
        "handlesAlerts" : false,            //< TODO
        "databaseEnabled" : false,          //< TODO
        "locationContextEnabled" : false,   //< TODO Target is 1.1
        "applicationCacheEnabled" : false,  //< TODO Support for AppCache (?)
        "browserConnectionEnabled" : false, //< TODO
        "cssSelectorsEnabled" : true,
        "webStorageEnabled" : false,        //< TODO support for LocalStorage/SessionStorage
        "rotatable" : false,                //< TODO Target is 1.1
        "acceptSslCerts" : false,           //< TODO
        "nativeEvents" : true,              //< TODO Only some commands are Native Events currently
        "unhandledPromptBehavior" : null,
        "proxy" : {                         //< TODO Support more proxy options - PhantomJS does allow setting from command line
            "proxyType" : _const.PROXY_TYPES.DIRECT
        },
        "webSecurityEnabled" : true
    },
    _negotiatedCapabilities = {
        "browserName"               : _defaultCapabilities.browserName,
        "version"                   : _defaultCapabilities.version,
        "driverName"                : _defaultCapabilities.driverName,
        "driverVersion"             : _defaultCapabilities.driverVersion,
        "platform"                  : _defaultCapabilities.platform,
        "javascriptEnabled"         : _defaultCapabilities.javascriptEnabled,
        "takesScreenshot"           : typeof(desiredCapabilities.takesScreenshot) === "undefined" ?
            _defaultCapabilities.takesScreenshot :
            desiredCapabilities.takesScreenshot,
        "handlesAlerts"             : _defaultCapabilities.handlesAlerts,
        "databaseEnabled"           : _defaultCapabilities.databaseEnabled,
        "locationContextEnabled"    : _defaultCapabilities.locationContextEnabled,
        "applicationCacheEnabled"   : _defaultCapabilities.applicationCacheEnabled,
        "browserConnectionEnabled"  : _defaultCapabilities.browserConnectionEnabled,
        "cssSelectorsEnabled"       : _defaultCapabilities.cssSelectorsEnabled,
        "webStorageEnabled"         : _defaultCapabilities.webStorageEnabled,
        "rotatable"                 : _defaultCapabilities.rotatable,
        "acceptSslCerts"            : _defaultCapabilities.acceptSslCerts,
        "nativeEvents"              : _defaultCapabilities.nativeEvents,
        "unhandledPromptBehavior"   : typeof(desiredCapabilities.unhandledPromptBehavior) === "undefined" ?
            _defaultCapabilities.unhandledPromptBehavior :
            desiredCapabilities.unhandledPromptBehavior,
        "proxy"                     : typeof(desiredCapabilities.proxy) === "undefined" ?
            _defaultCapabilities.proxy :
            desiredCapabilities.proxy,
        "webSecurityEnabled"        : typeof(desiredCapabilities.webSecurityEnabled) === "undefined" ?
            _defaultCapabilities.webSecurityEnabled :
            desiredCapabilities.webSecurityEnabled
    },
    // NOTE: This value is needed for Timeouts Upper-bound limit.
    // "setTimeout/setInterval" accept only 32 bit integers, even though Number are all Doubles (go figure!)
    // Interesting details here: {@link http://stackoverflow.com/a/4995054}.
    _max32bitInt = Math.pow(2, 31) -1,      //< Max 32bit Int
    _timeouts = {
        "script"            : 30000,
        "implicit"          : 0,
        "page load"         : 300000,
    },
    _windows = {},  //< NOTE: windows are "webpage" in Phantom-dialect
    _currentWindowHandle = null,
    _cookieJar = require('cookiejar').create(),
    _id = require("./third_party/uuid.js").v1(),
    _inputs = ghostdriver.Inputs(),
    _capsPageSettingsPref = "phantomjs.page.settings.",
    _capsPageCustomHeadersPref = "phantomjs.page.customHeaders.",
    _capsPageZoomFactor = "phantomjs.page.zoomFactor",
    _capsPageBlacklistPref = "phantomjs.page.blacklist",
    _capsPageWhitelistPref = "phantomjs.page.whitelist",
    _capsUnhandledPromptBehavior = "unhandledPromptBehavior",
    _capsLoggingPref = "loggingPrefs",
    _capsBrowserLoggerPref = "OFF",
    _capsHarLoggerPref = "OFF",
    _pageBlacklistFilter,
    _pageWhitelistFilter,
    _capsPageSettingsProxyPref = "proxy",
    _pageSettings = {},
    _pageZoomFactor = 1,
    _additionalPageSettings = {
        resourceTimeout: null,
        userName: null,
        password: null
    },
    _pageCustomHeaders = {},
    _log = ghostdriver.logger.create("Session [" + _id + "]"),
    k, settingKey, headerKey, proxySettings;

    var
    /**
     * Parses proxy JSON object and return proxy settings for phantom
     *
     * @param proxyCapability proxy JSON Object: @see https://code.google.com/p/selenium/wiki/DesiredCapabilities
     */
    _getProxySettingsFromCapabilities = function(proxyCapability) {
        var proxySettings = {};
        if (proxyCapability["proxyType"].toLowerCase() == _const.PROXY_TYPES.MANUAL) {      //< TODO: support other options
            if (proxyCapability["httpProxy"] !== "null") {                                  //< TODO: support other proxy types
                var urlParts = proxyCapability["httpProxy"].split(':');
                proxySettings["ip"] = urlParts[0];
                proxySettings["port"] = urlParts[1];
                proxySettings["proxyType"] = "http";
                proxySettings["user"] = "";
                proxySettings["password"] = "";

                return proxySettings;
            }
        }
        return proxySettings;
    };

    // Searching for `phantomjs.settings.* and phantomjs.customHeaders.* phantomjs.page.zoomFactor` in the Desired Capabilities and merging with the Negotiated Capabilities
    // Possible values for settings: @see http://phantomjs.org/api/webpage/property/settings.html.
    // Possible values for customHeaders: @see http://phantomjs.org/api/webpage/property/custom-headers.html.
    for (k in desiredCapabilities) {
        if (k.indexOf(_capsPageSettingsPref) === 0) {
            settingKey = k.substring(_capsPageSettingsPref.length);
            if (settingKey.length > 0) {
                _negotiatedCapabilities[k] = desiredCapabilities[k];
                _pageSettings[settingKey] = desiredCapabilities[k];
            }
        }
        if (k.indexOf(_capsPageCustomHeadersPref) === 0) {
            headerKey = k.substring(_capsPageCustomHeadersPref.length);
            if (headerKey.length > 0) {
                _negotiatedCapabilities[k] = desiredCapabilities[k];
                _pageCustomHeaders[headerKey] = desiredCapabilities[k];
            }
        }
        if (k.indexOf(_capsPageZoomFactor) === 0){
            _negotiatedCapabilities[k] = desiredCapabilities[k];
            _pageZoomFactor = desiredCapabilities[k];
        }
        if (k.indexOf(_capsPageBlacklistPref) === 0) {
            const pageBlacklist = [];
            const pageBlacklistLength = desiredCapabilities[k].length;
            for(var i = 0; i < pageBlacklistLength; i++) {
                pageBlacklist.push(new RegExp(desiredCapabilities[k][i]));
            }
            _pageBlacklistFilter = function(url, net) {
                for(var i = 0; i < pageBlacklistLength; i++) {
                    if(url.search(pageBlacklist[i]) !== -1) {
                        net.abort();
                        _log.debug("blacklist abort " + url);
                    }
                }
            }
        }
        if (k.indexOf(_capsPageWhitelistPref) === 0) {
            const pageWhitelist = [];
            const pageWhitelistLength = desiredCapabilities[k].length;
            for(var i = 0; i < pageWhitelistLength; i++) {
                pageWhitelist.push(new RegExp(desiredCapabilities[k][i]));
            }
            _pageWhitelistFilter = function(url, net) {
                for(var i = 0; i < pageWhitelistLength; i++) {
                    if(url.search(pageWhitelist[i]) !== -1) {
                        return;
                    }
                }
                net.abort();
                _log.debug("whitelist abort " + url);
            }
        }
        if (k.indexOf(_capsPageSettingsProxyPref) === 0) {
            proxySettings = _getProxySettingsFromCapabilities(desiredCapabilities[k]);
            phantom.setProxy(proxySettings["ip"], proxySettings["port"], proxySettings["proxyType"], proxySettings["user"], proxySettings["password"]);
        }
        if (k.indexOf(_capsLoggingPref) === 0) {
            if (desiredCapabilities[k][_const.LOG_TYPES.BROWSER]) {
                _capsBrowserLoggerPref = desiredCapabilities[k][_const.LOG_TYPES.BROWSER] || _capsBrowserLoggerPref;
            }
            if (desiredCapabilities[k][_const.LOG_TYPES.HAR]) {
                _capsHarLoggerPref = desiredCapabilities[k][_const.LOG_TYPES.HAR] || _capsHarLoggerPref;
            }
        }
    }

    var
    /**
     * Executes a function and waits for Load to happen.
     *
     * @param code Code to execute: a Function or just plain code
     * @param onLoadFunc Function to execute when page finishes Loading
     * @param onErrorFunc Function to execute in case of error
     *        (eg. Javascript error, page load problem or timeout).
     * @param execTypeOpt Decides if to "apply" the function directly or page."eval" it.
     *                    Optional. Default value is "apply".
     */
    _execFuncAndWaitForLoadDecorator = function(code, onLoadFunc, onErrorFunc, execTypeOpt) {
        // convert 'arguments' to a real Array
        var args = Array.prototype.splice.call(arguments, 0),
            thisPage = this,
            onLoadFinishedArgs = null,
            onErrorArgs = null;

        // Normalize "execTypeOpt" value
        if (typeof(execTypeOpt) === "undefined" ||
            (execTypeOpt !== "apply" && execTypeOpt !== "eval")) {
            execTypeOpt = "apply";
        }

        thisPage._onLoadFinishedLatch = false;
        // Execute "code"
        if (execTypeOpt === "eval") {
            // Remove arguments used by this function before providing them to the target code.
            // NOTE: Passing 'code' (to evaluate) and '0' (timeout) to 'evaluateAsync'.
            args.splice(0, 3, code, 0);
            // Invoke the Page Eval with the provided function
            this.evaluateAsync.apply(this, args);
        } else {
            // Remove arguments used by this function before providing them to the target function.
            args.splice(0, 3);
            // "Apply" the provided function
            code.apply(this, args);
        }

        // Wait 10ms before proceeding any further: in this window of time
        // the page can react and start loading (if it has to).
        setTimeout(function() {
            var loadingStartedTs = new Date().getTime(),
                checkLoadingFinished;

            checkLoadingFinished = function() {
                if (!_isLoading()) {               //< page finished loading
                    _log.debug("_execFuncAndWaitForLoadDecorator", "Page Loading in Session: false");

                    if (!thisPage && thisPage._onLoadFinishedLatch) {
                        _log.debug("_execFuncAndWaitForLoadDecorator", "Handle Load Finish Event");
                        // Report the result of the "Load Finished" event
                        onLoadFunc.apply(thisPage, Array.prototype.slice.call(arguments));
                    } else {
                        _log.debug("_execFuncAndWaitForLoadDecorator", "No Load Finish Event Detected");
                        // No page load was caused: just report "success"
                        onLoadFunc.call(thisPage, "success");
                    }

                    return;
                } // else:
                _log.debug("_execFuncAndWaitForLoadDecorator", "Page Loading in Session: true");

                // Timeout error?
                if (new Date().getTime() - loadingStartedTs > _getPageLoadTimeout()) {
                    // Report the "Timeout" event
                    onErrorFunc.call(thisPage, "timeout");
                    return;
                }

                // Retry in 100ms
                setTimeout(checkLoadingFinished, 100);
            };
            checkLoadingFinished();
        }, 10);     //< 10ms
    },

    /**
     * Wait for Page to be done Loading before executing of callback.
     * Also, it considers "Page Timeout" to avoid waiting indefinitely.
     * NOTE: This is useful for cases where it's not certain a certain action
     * just executed MIGHT cause a page to start loading.
     * It's a "best effort" approach and the user is given the use of
     * "Page Timeout" to tune to their needs.
     *
     * @param callback Function to execute when done or timed out
     */
    _waitIfLoadingDecorator = function(callback) {
        var thisPage = this,
            waitStartedTs = new Date().getTime(),
            checkDoneLoading;

        checkDoneLoading = function() {
            if (!_isLoading()             //< Session is not loading (any more?)
                || (new Date().getTime() - waitStartedTs > _getPageLoadTimeout())) {    //< OR Page Timeout expired
                callback.call(thisPage);
                return;
            }

            _log.debug("_waitIfLoading", "Still loading (wait using Implicit Timeout)");

            // Retry in 10ms
            setTimeout(checkDoneLoading, 10);
        };
        checkDoneLoading();
    },

    _oneShotCallbackFactory = function(page, callbackName) {
        return function() {
            var oneShotCallbackName = callbackName + _const.ONE_SHOT_POSTFIX,
                i, retVal;

            try {
                // If there are callback functions registered
                if (page[oneShotCallbackName] instanceof Array
                    && page[oneShotCallbackName].length > 0) {
                    _log.debug("_oneShotCallback", callbackName);

                    // Invoke all the callback functions (once)
                    for (i = page[oneShotCallbackName].length -1; i >= 0; --i) {
                        retVal = page[oneShotCallbackName][i].apply(page, arguments);
                    }

                    // Remove all the callback functions now
                    page[oneShotCallbackName] = [];
                }
            } catch (e) {
                // In case the "page" object has been closed,
                // the code above will fail: that's OK.
            }

            // Return (latest) value
            return retVal;
        };
    },

    _setOneShotCallbackDecorator = function(callbackName, handlerFunc) {
        var oneShotCallbackName = callbackName + _const.ONE_SHOT_POSTFIX;

        // Initialize array of One Shot Callbacks
        if (!(this[oneShotCallbackName] instanceof Array)) {
            this[oneShotCallbackName] = [];
        }
        this[oneShotCallbackName].push(handlerFunc);
    },

    _decoratePromptBehavior = function(newPage) {
        var _unhandledPromptBehavior = _negotiatedCapabilities["unhandledPromptBehavior"],
            confirmValue;

        if (_unhandledPromptBehavior !== "accept" && _unhandledPromptBehavior !== "dismiss") {
            return;
        }

        _log.info("_decoratePromptBehavior");

        newPage.onAlert = function(msg) {
            _log.debug("ALERT: " + msg);
        }

        newPage.onPrompt = function(msg, val) {
            _log.debug("PROMPT: " + msg);
            return val;
        }

        if (_unhandledPromptBehavior === "accept") {
            confirmValue = true;
        } else {
            confirmValue = false;
        }

        newPage.onConfirm = function(msg) {
            _log.debug("CONFIRM: " + msg);
            return confirmValue;
        }
    },

    // Add any new page to the "_windows" container of this session
    _addNewPage = function(newPage) {
        _log.debug("_addNewPage");

        // decorate the new Window/Page
        newPage = _decorateNewWindow(newPage);
        // set session-specific CookieJar
        newPage.cookieJar = _cookieJar;
        // store the Window/Page by WindowHandle
        _windows[newPage.windowHandle] = newPage;
    },

    // Delete any closing page from the "_windows" container of this session
    _deleteClosingPage = function(closingPage) {
        _log.debug("_deleteClosingPage");

        // Need to be defensive, as the "closing" can be cause by Client Commands
        if (_windows.hasOwnProperty(closingPage.windowHandle)) {
            delete _windows[closingPage.windowHandle];
        }
    },

    _decorateNewWindow = function(page) {
        var k;

        // Decorating:
        // 0. Pages lifetime will be managed by Driver, not the pages
        page.ownsPages = false;

        // 1. Random Window Handle
        page.windowHandle = require("./third_party/uuid.js").v1();

        // 2. Initialize the One-Shot Callbacks
        page["onUrlChanged"] = _oneShotCallbackFactory(page, "onUrlChanged");
        page["onFilePicker"] = _oneShotCallbackFactory(page, "onFilePicker");
        page["onCallback"] = _oneShotCallbackFactory(page, "onCallback");

        // 3. Utility methods
        page.execFuncAndWaitForLoad = _execFuncAndWaitForLoadDecorator;
        page.setOneShotCallback = _setOneShotCallbackDecorator;
        page.waitIfLoading = _waitIfLoadingDecorator;

        // 4. Store every newly created page
        page.onPageCreated = _addNewPage;

        // 5. Remove every closing page
        page.onClosing = _deleteClosingPage;

        // 6. Applying Page settings received via capabilities
        for (k in _pageSettings) {
            // Apply setting only if really supported by PhantomJS
            if (page.settings.hasOwnProperty(k) || _additionalPageSettings.hasOwnProperty(k)) {
                page.settings[k] = _pageSettings[k];
            }
        }

        // 7. Applying Page custom headers received via capabilities
        // fix custom headers per ariya/phantomjs#13621 and detro/ghostdriver#489
        if ("Accept-Encoding" in _pageCustomHeaders) {
            _log.warn("Custom header \"Accept-Encoding\" is not supported.  see ariya/phantomjs#13621");
            delete _pageCustomHeaders["Accept-Encoding"]
        }
        page.customHeaders = _pageCustomHeaders;

        // 8. Applying Page zoomFactor
        page.zoomFactor = _pageZoomFactor;

        // 9. Log Page internal errors
        page.browserLog = ghostdriver.webdriver_logger.create(_capsBrowserLoggerPref);
        page.onError = function(errorMsg, errorStack) {
            var stack = '';

            // Prep the "stack" part of the message
            errorStack.forEach(function (stackEntry, idx, arr) {
                stack += "  " //< a bit of indentation
                    + (stackEntry.function || "(anonymous function)")
                    + " (" + stackEntry.file + ":" + stackEntry.line + ")";
                stack += idx < arr.length - 1 ? "\n" : "";
            });

            // Log as error
            _log.error("page.onError", "msg: " + errorMsg);
            _log.error("page.onError", "stack:\n" + stack);

            // Register as part of the "browser" log
            page.browserLog.push(_createLogEntry("WARNING", errorMsg + "\n" + stack));
        };

        // 10. Log Page console messages
        page.onConsoleMessage = function(msg, lineNum, sourceId) {
            // Log as debug
            // Register as part of the "browser" log
            page.browserLog.push(_createLogEntry("INFO", msg + " (" + sourceId + ":" + lineNum + ")"));
        };

        // 11. Log Page network activity
        page.resources = ghostdriver.webdriver_logger.create(_capsHarLoggerPref);
        page.startTime = null;
        page.endTime = null;

        // register onLoad callbacks to detect page load
        page._onLoadLatch = false;
        page._onLoadFinishedLatch = false;
        page.onLoadStarted = function() {
            page._onLoadLatch = true;
            page.startTime = new Date();
            _log.debug("page.onLoadStarted");
        };
        page.onLoadFinished = function() {
            page._onLoadLatch = false;
            page._onLoadFinishedLatch = true;
            page.endTime = new Date();
            _log.debug("page.onLoadFinished");
        };

        page.onResourceRequested = function (req, net) {
            if(_pageWhitelistFilter) { _pageWhitelistFilter(req.url, net); }
            if(_pageBlacklistFilter) { _pageBlacklistFilter(req.url, net); }

            _log.debug("page.onResourceRequested", JSON.stringify(req));

            // Register HTTP Request
            page.resources.push({
                id: req.id,
                request: req
            });
        };
        page.onResourceReceived = function (res) {
            _log.debug("page.onResourceReceived", JSON.stringify(res));

            // Register HTTP Response
            if (res.stage === 'start') {
                page.resources.push({
                    id: res.id,
                    startReply: res
                });
            } else if (res.stage === 'end') {
                page.resources.push({
                    id: res.id,
                    endReply: res
                });
            }
        };
        page.onResourceError = function(resError) {
            _log.debug("page.onResourceError", JSON.stringify(resError));

            // Register HTTP Error
            page.resources.push({
                id: resError.id,
                error: resError
            });
        };
        page.onResourceTimeout = function(req) {
            _log.debug("page.onResourceTimeout", JSON.stringify(req));

            // Register HTTP Timeout
            page.resources.push({
                id: req.id,
                error: req
            });
        };
        page.onNavigationRequested = function(url, type, willNavigate, main) {
            // Clear page log before page loading
            if (main && willNavigate) {
                _clearPageLog(page);
            }
        };

        _decoratePromptBehavior(page);

        // NOTE: The most common desktop screen resolution used online is currently: 1366x768
        // See http://gs.statcounter.com/#resolution-ww-monthly-201307-201312.
        // Jan 2017
        page.viewportSize = {
            width   : 1366,
            height  : 768
        };

        _log.info("page.settings", JSON.stringify(page.settings));
        _log.info("page.customHeaders: ", JSON.stringify(page.customHeaders));
        _log.info("page.zoomFactor: ", JSON.stringify(page.zoomFactor));

        return page;
    },

    _createLogEntry = function(level, message) {
        return {
            "level"     : level,
            "message"   : message,
            "timestamp" : (new Date()).getTime()
        };
    },

    /**
     * Is any window in this Session Loading?
     * @returns "true" if at least 1 window is loading.
     */
    _isLoading = function() {
        var wHandle, _window;

        for (wHandle in _windows) {
            _window = _windows[wHandle];
            if (_window._onLoadLatch || (_window.loadingProgress > 0 && _window.loadingProgress < 100)) {
                return true;
            }
        }

        return false;
    },

    /**
     * According to log method specification we have to clear log after each page refresh.
     * https://code.google.com/p/selenium/wiki/JsonWireProtocol#/session/:sessionId/log
     * @param {Object} page
     * @private
     */
    _clearPageLog = function (page) {
        page.resources.log = [];
        page.browserLog.log = [];
    },

    _getWindow = function(handleOrName) {
        var page = null,
            k;

        if (_isValidWindowHandle(handleOrName)) {
            // Search by "handle"
            page = _windows[handleOrName];
        } else {
            // Search by "name"
            for (k in _windows) {
                if (_windows[k].windowName === handleOrName) {
                    page = _windows[k];
                    break;
                }
            }
        }

        return page;
    },

    _init = function() {
        var page;

        // Ensure a Current Window is available, if it's found to be `null`
        if (_currentWindowHandle === null) {
            // Create the first Window/Page
            page = require("webpage").create();
            // Decorate it with listeners and helpers
            page = _decorateNewWindow(page);
            // set session-specific CookieJar
            page.cookieJar = _cookieJar;
            // Make the new Window, the Current Window
            _currentWindowHandle = page.windowHandle;
            // Store by WindowHandle
            _windows[_currentWindowHandle] = page;
        }
    },

    _getCurrentWindow = function() {
        var page = null;

        if (_windows.hasOwnProperty(_currentWindowHandle)) {
            page = _windows[_currentWindowHandle];
        }

        // TODO Handle "null" cases throwing a "no such window" error

        return page;
    },

    _switchToWindow = function(handleOrName) {
        var page = _getWindow(handleOrName);

        if (page !== null) {
            // Switch current window and return "true"
            _currentWindowHandle = page.windowHandle;
            // Switch to the Main Frame of that window
            page.switchToMainFrame();
            return true;
        }

        // Couldn't find the window, so return "false"
        return false;
    },

    _closeCurrentWindow = function() {
        if (_currentWindowHandle !== null) {
            return _closeWindow(_currentWindowHandle);
        }
        return false;
    },

    _closeWindow = function(handleOrName) {
        var page = _getWindow(handleOrName),
            handle;

        if (page !== null) {
            handle = page.windowHandle;
            _windows[handle].close();
            delete _windows[handle];
            return true;
        }
        return false;
    },

    _getWindowsCount = function() {
        return Object.keys(_windows).length;
    },

    _getCurrentWindowHandle = function() {
        if (!_isValidWindowHandle(_currentWindowHandle)) {
            return null;
        }
        return _currentWindowHandle;
    },

    _isValidWindowHandle = function(handle) {
        return _windows.hasOwnProperty(handle);
    },

    _getWindowHandles = function() {
        return Object.keys(_windows);
    },

    _setTimeout = function(type, ms) {
        // In case the chosen timeout is less than 0, we reset it to `_max32bitInt`
        if (ms < 0) {
            _timeouts[type] = _max32bitInt;
        } else {
            _timeouts[type] = ms;
        }
    },

    _getTimeout = function(type) {
        return _timeouts[type];
    },

    _getScriptTimeout = function() {
        return _getTimeout(_const.TIMEOUT_NAMES.SCRIPT);
    },

    _getImplicitTimeout = function() {
        return _getTimeout(_const.TIMEOUT_NAMES.IMPLICIT);
    },

    _getPageLoadTimeout = function() {
        return _getTimeout(_const.TIMEOUT_NAMES.PAGE_LOAD);
    },

    _setScriptTimeout = function(ms) {
        _setTimeout(_const.TIMEOUT_NAMES.SCRIPT, ms);
    },

    _setImplicitTimeout = function(ms) {
        _setTimeout(_const.TIMEOUT_NAMES.IMPLICIT, ms);
    },

    _setPageLoadTimeout = function(ms) {
        _setTimeout(_const.TIMEOUT_NAMES.PAGE_LOAD, ms);
    },

    _executePhantomJS = function(page, script, args) {
        try {
            var code = new Function(script);
            return code.apply(page, args);
        } catch (e) {
            return e;
        }
    },

    _aboutToDelete = function() {
        var k;

        // Close current window first
        _closeCurrentWindow();

        // Releasing page resources and deleting the objects
        for (k in _windows) {
            _closeWindow(k);
        }

        // Release CookieJar resources
        _cookieJar.close();
    },

    _getLog = function (type) {
        var har, i, entry, attrName,
            page, tmp, tmpResMap;

        // Return "HAR" as Log Type "har"
        if (type === _const.LOG_TYPES.HAR) {
            har = require('./third_party/har.js');
            page = _getCurrentWindow();

            tmpResMap = {};
            for (i = 0; i < page.resources.log.length; i++) {
                entry = page.resources.log[i];
                if (!tmpResMap[entry.id]) {
                    tmpResMap[entry.id] = {
                        id: entry.id,
                        request: null,
                        startReply: null,
                        endReply: null,
                        error: null
                    }
                }
                for (attrName in entry) {
                    tmpResMap[entry.id][attrName] = entry[attrName];
                }
            }
            page.resources.log = [];
            tmp = Object.keys(tmpResMap).sort();
            for (i in tmp) {
                page.resources.push(tmpResMap[tmp[i]]);
            }

            tmp = [];
            tmp.push(_createLogEntry(
                "INFO",
                JSON.stringify(har.createHar(page, page.resources.log))));
            page.resources.log = [];
            return tmp;
        }

        // Return Browser Console Log
        if (type === _const.LOG_TYPES.BROWSER) {
            page = _getCurrentWindow();
            tmp = page.browserLog.log;
            page.browserLog.log = [];
            return tmp;
        }

        // Return empty Log
        return [];
    },

    _getLogTypes = function () {
        var logTypes = [], k;

        for (k in _const.LOG_TYPES) {
            logTypes.push(_const.LOG_TYPES[k]);
        }

        return logTypes;
    },

    _getFrameOffset = function(page) {
        return page.evaluate(function() {
            var win = window,
                offset = {top: 0, left: 0},
                style,
                rect;

            while(win.frameElement) {
                rect = win.frameElement.getClientRects()[0];
                style = win.getComputedStyle(win.frameElement);
                win = win.parent;

                offset.top += rect.top + parseInt(style.getPropertyValue('padding-top'), 10);
                offset.left += rect.left + parseInt(style.getPropertyValue('padding-left'), 10);
            }

            return offset;
        });
    };

    // Initialize the Session.
    // Particularly, create the first empty page/window.
    _init();

    _log.debug("Session.desiredCapabilities", JSON.stringify(desiredCapabilities));
    _log.info("Session.negotiatedCapabilities", JSON.stringify(_negotiatedCapabilities));

    // public:
    return {
        getCapabilities : function() { return _negotiatedCapabilities; },
        getId : function() { return _id; },
        switchToWindow : _switchToWindow,
        getCurrentWindow : _getCurrentWindow,
        closeCurrentWindow : _closeCurrentWindow,
        getWindow : _getWindow,
        closeWindow : _closeWindow,
        getWindowsCount : _getWindowsCount,
        getCurrentWindowHandle : _getCurrentWindowHandle,
        getWindowHandles : _getWindowHandles,
        isValidWindowHandle : _isValidWindowHandle,
        aboutToDelete : _aboutToDelete,
        inputs : _inputs,
        setScriptTimeout : _setScriptTimeout,
        setImplicitTimeout : _setImplicitTimeout,
        setPageLoadTimeout : _setPageLoadTimeout,
        getScriptTimeout : _getScriptTimeout,
        getImplicitTimeout : _getImplicitTimeout,
        getPageLoadTimeout : _getPageLoadTimeout,
        executePhantomJS : _executePhantomJS,
        timeoutNames : _const.TIMEOUT_NAMES,
        isLoading : _isLoading,
        getLog: _getLog,
        getLogTypes: _getLogTypes,
        getFrameOffset: _getFrameOffset
    };
};
