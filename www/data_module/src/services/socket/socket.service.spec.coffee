describe 'Socket service', ->

    beforeEach module 'bbData'

    $rootScope = $location = socketService = socket = webSocketBackend = undefined
    injected = ($injector) ->
        $rootScope = $injector.get('$rootScope')
        $location = $injector.get('$location')
        socketService = $injector.get('socketService')
        webSocketBackend = $injector.get('webSocketBackendService')
        socket = webSocketBackend.getWebSocket()
        spyOn(socket, 'send').and.callThrough()
        spyOn(socketService, 'getWebSocket').and.callThrough()

    beforeEach(inject(injected))

    it 'should be defined', ->
        expect(socketService).toBeDefined()

    it 'should call the onMessage function when a message is an update message', ->
        socketService.open()
        socket.readyState = socket.OPEN
        socketService.onMessage = jasmine.createSpy('onMessage')
        update = {k: 'key', m: 'message'}
        updateMessage = angular.toJson(update)

        webSocketBackend.send(updateMessage)

        expect(socketService.onMessage).not.toHaveBeenCalled()
        $rootScope.$apply -> webSocketBackend.flush()
        expect(socketService.onMessage).toHaveBeenCalledWith(update.k, update.m)

    it 'should call the onClose function when the connection closes', ->
        socketService.open()
        socketService.onClose = jasmine.createSpy('onClose')
        expect(socketService.onClose).not.toHaveBeenCalled()
        socketService.close()
        expect(socketService.onClose).toHaveBeenCalled()

    it 'should add an _id to every message', ->
        socketService.open()
        socket.readyState = socket.OPEN
        expect(socket.send).not.toHaveBeenCalled()
        socketService.send({})
        expect(socket.send).toHaveBeenCalledWith(jasmine.any(String))
        argument = socket.send.calls.argsFor(0)[0]
        expect(angular.fromJson(argument)._id).toBeDefined()

    it 'should send messages waiting in the queue when the connection is open', ->
        socketService.open()
        # socket is opening
        socket.readyState = 0
        msg1 = {a: 1}
        msg2 = {b: 2}
        msg3 = {c: 3}
        socketService.send(msg1)
        socketService.send(msg2)
        expect(socket.send).not.toHaveBeenCalled()
        # open the socket
        socket.onopen()
        expect(socket.send).toHaveBeenCalled()
        expect(webSocketBackend.receiveQueue).toContain(angular.toJson(msg1))
        expect(webSocketBackend.receiveQueue).toContain(angular.toJson(msg2))
        expect(webSocketBackend.receiveQueue).not.toContain(angular.toJson(msg3))

    it 'should resolve the promise when a response is received with status code of 200', ->
        socketService.open()
        socket.readyState = socket.OPEN
        promise = socketService.send(cmd: 'command')
        handler = jasmine.createSpy('handler')
        promise.then(handler)
        # the promise should not be resolved
        expect(handler).not.toHaveBeenCalled()

        # get the id from the message
        argument = socket.send.calls.argsFor(0)[0]
        id = angular.fromJson(argument)._id
        # create a response message with status code 200
        response = angular.toJson({_id: id, code: 200})

        # send the message
        webSocketBackend.send(response)
        $rootScope.$apply ->
            webSocketBackend.flush()
        # the promise should be resolved
        expect(handler).toHaveBeenCalled()

    it 'should reject the promise when a response is received with a status code of not 200', ->
        socketService.open()
        socket.readyState = socket.OPEN
        promise = socketService.send(cmd: 'command')
        handler = jasmine.createSpy('handler')
        errorHandler = jasmine.createSpy('errorHandler')
        promise.then(handler, errorHandler)
        # the promise should not be resolved
        expect(handler).not.toHaveBeenCalled()
        expect(errorHandler).not.toHaveBeenCalled()

        # get the id from the message
        argument = socket.send.calls.argsFor(0)[0]
        id = angular.fromJson(argument)._id
        # create a response message with status code 400
        response = angular.toJson({_id: id, code: 400})

        # send the message
        webSocketBackend.send(response)
        $rootScope.$apply -> webSocketBackend.flush()
        # the promise should be rejected
        expect(handler).not.toHaveBeenCalled()
        expect(errorHandler).toHaveBeenCalled()

    describe 'open()', ->

        it 'should call getWebSocket', ->
            expect(socketService.getWebSocket).not.toHaveBeenCalled()
            socketService.open()
            expect(socketService.getWebSocket).toHaveBeenCalled()

    describe 'close()', ->

        it 'should call socket.close', ->
            socketService.open()

            spyOn(socket, 'close').and.callThrough()
            expect(socket.close).not.toHaveBeenCalled()
            socketService.close()
            expect(socket.close).toHaveBeenCalled()

    describe 'flush()', ->

        it 'should send the messages waiting in the queue', ->
            socketService.open()

            messages = [
                {a: 1}
                {b: 2}
                {c: 3}
            ]

            for m in messages
                m = angular.toJson(m)
                socketService.queue.push(m)

            expect(socket.send).not.toHaveBeenCalled()
            socketService.flush()
            for m in messages
                m = angular.toJson(m)
                expect(socket.send).toHaveBeenCalledWith(m)

    describe 'nextId()', ->

        it 'should return different ids', ->
            id1 = socketService.nextId()
            id2 = socketService.nextId()

            expect(id1).not.toEqual(id2)

    describe 'getUrl()', ->

        it 'should return the WebSocket url based on the host and port (localhost)', ->
            host = 'localhost'
            port = 8080
            spyOn($location, 'host').and.returnValue(host)
            spyOn($location, 'port').and.returnValue(port)

            url = socketService.getUrl()
            expect(url).toBe('ws://localhost:8080/ws')

        it 'should return the WebSocket url based on the host and port', ->
            host = 'buildbot.test'
            port = 80
            spyOn($location, 'host').and.returnValue(host)
            spyOn($location, 'port').and.returnValue(port)

            url = socketService.getUrl()
            expect(url).toBe('ws://buildbot.test/ws')

        it 'should return the WebSocket url based on the host and port and protocol', ->
            host = 'buildbot.test'
            port = 443
            protocol = 'https'
            spyOn($location, 'host').and.returnValue(host)
            spyOn($location, 'port').and.returnValue(port)
            spyOn($location, 'protocol').and.returnValue(protocol)

            url = socketService.getUrl()
            expect(url).toBe('wss://buildbot.test/ws')

        it 'should return the WebSocket url based on the host and port and protocol and basedir', ->
            host = 'buildbot.test'
            port = 443
            protocol = 'https'
            path = 'travis/'
            spyOn($location, 'host').and.returnValue(host)
            spyOn($location, 'port').and.returnValue(port)
            spyOn($location, 'protocol').and.returnValue(protocol)
            spyOn($location, 'path').and.returnValue(path)

            url = socketService.getUrl()
            expect(url).toBe('wss://buildbot.test/travis/ws')
