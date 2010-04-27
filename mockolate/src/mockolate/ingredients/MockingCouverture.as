package mockolate.ingredients
{    
    import asx.array.contains;
    import asx.array.detect;
    import asx.array.empty;
    import asx.array.filter;
    import asx.array.map;
    import asx.array.reject;
    import asx.fn.getProperty;
    import asx.string.substitute;
    
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.IEventDispatcher;
    import flash.utils.getQualifiedClassName;
    
    import mockolate.errors.ExpectationError;
    import mockolate.errors.InvocationError;
    import mockolate.errors.MockolateError;
    import mockolate.errors.VerificationError;
    import mockolate.ingredients.answers.Answer;
    import mockolate.ingredients.answers.CallsAnswer;
    import mockolate.ingredients.answers.DispatchesEventAnswer;
    import mockolate.ingredients.answers.MethodInvokingAnswer;
    import mockolate.ingredients.answers.PassThroughAnswer;
    import mockolate.ingredients.answers.ReturnsAnswer;
    import mockolate.ingredients.answers.ThrowsAnswer;
    import mockolate.ingredients.rpc.HTTPServiceMockingCouvertureDecorator;
    
    import mx.rpc.http.HTTPService;
    
    import org.hamcrest.Matcher;
    import org.hamcrest.StringDescription;
    import org.hamcrest.collection.array;
    import org.hamcrest.collection.emptyArray;
    import org.hamcrest.core.anyOf;
    import org.hamcrest.core.anything;
    import org.hamcrest.core.describedAs;
    import org.hamcrest.date.dateEqual;
    import org.hamcrest.number.greaterThan;
    import org.hamcrest.number.greaterThanOrEqualTo;
    import org.hamcrest.number.lessThan;
    import org.hamcrest.number.lessThanOrEqualTo;
    import org.hamcrest.object.equalTo;
    import org.hamcrest.object.instanceOf;
    import org.hamcrest.object.nullValue;
    import org.hamcrest.text.re;
    
    use namespace mockolate_ingredient;
    
	// FIXME the eventDispatcher stuff is hacky, unusable for other similar cases where we want to proceed.
    
    /**
     * Mock & Stub behaviour of the target, such as:
     * <ul>
     * <li>return values, </li>
     * <li>calling functions, </li>
     * <li>dispatching events, </li>
     * <li>throwing errors. </li>
     * </ul>
     * 
     * @author drewbourne
     */
    public class MockingCouverture extends Couverture
    {
        private var _expectations:Array;
        private var _mockExpectations:Array;
        private var _stubExpectations:Array;
        private var _currentExpectation:Expectation;
        private var _expectationsAsMocks:Boolean;
        private var _eventDispatcher:IEventDispatcher;
        private var _eventDispatcherMethods:Array = ['addEventListener', 'dispatchEvent', 'hasEventListener', 'removeEventListener', 'willTrigger']; 
        
        /**
         * Constructor. 
         */
        public function MockingCouverture(mockolate:Mockolate)
        {
            super(mockolate);
            
            _expectations = [];
            _mockExpectations = [];
            _stubExpectations = [];
            _expectationsAsMocks = true;
        }
        
        //
        //	Public API
        //
        
        //
        //	mocking and stubbing behaviours
        //
        
        /**
         * Use <code>mock()</code> when you want to ensure that method or 
         * property is called.
         * 
         * Sets the expectation mode to create required Expectations. Required 
         * Expectations will be checked when <code>verify(instance)</code> is 
         * called.
         * 
         * @see mockolate#mock()
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("toString").returns("[Instance]");
         * </listing>
         */
        public function mock():MockingCouverture
        {
        	_expectationsAsMocks = true;
        	return this;
        }

        /**
         * Use <code>stub()</code> when you want to add behaviour to a method
         * or property that MAY be used. 
         * 
         * Sets the expectation mode to create possible expectations. Possible 
         * Expectations will NOT be checked when <code>verify(instance)</code> 
         * is called. They are used to define support behaviour.
         * 
         * @see mockolate#stub()
         * 
         * @example
         * <listing version="3.0">
         * 	stub(instance).method("toString").returns("[Instance]");
         * </listing> 
         */
        public function stub():MockingCouverture
        {
        	_expectationsAsMocks = false;
        	return this;
        }
        
        // FIXME should return a MethodMockingCouverture that hides method() and property()
        /**
         * Defines an Expectation of the given method name.
         * 
         * @param name Name of the method to expect.
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("toString").returns("[Instance]");
         * </listing>
         */
        public function method(name:String/*, ns:String=null*/):MockingCouverture
        {
            // FIXME this _really_ should check that the method actually exists on the Class we are mocking
            // FIXME when this checks if the method exists, remember we have to support Proxy as well! 
            
            createMethodExpectation(name, null);
            
            // when expectation mode is mock
            // than should be called at least once
            // -- will be overridden if set by the user. 
            if (mockolate.isStrict)
            	atLeast(1);
            
            return this;
        }
        
        // Should return a PropertyMockingCouverture that hides method() and property() and provides only arg() not args()
        /**
         * Defines an Expectation for the given property name.
         * 
         * @param name Name of the method to expect.
         * 
         * @example
         * <listing version="3.0">
         * 	stub(instance).method("toString").returns("[Instance]");
         * </listing>  
         */
        public function property(name:String, ns:String=null):MockingCouverture
        {
            // FIXME this _really_ should check that the property actually exists on the Class we are mocking
            // FIXME when this checks if the method exists, remember we have to support Proxy as well!
            
            createPropertyExpectation(name, ns);
            
            // when expectation mode is mock
            // than should be called at least once
            // -- will be overridden if set by the user. 
            if (mockolate.isStrict)
            	atLeast(1);            
                        
            return this;
        }
        
        /**
         * Use <code>arg()</code> to define a single value or Matcher as the 
         * expected arguments. Typically used with property expectations to 
         * define the expected argument value for the property setter.
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).property("enabled").arg(Boolean);
         * </listing> 
         */
        public function arg(value:Object):MockingCouverture
        {
            // FIXME this _really_ should check that the method or property accepts the number of matchers given.
            // we can ignore the types of the matchers though, it will fail when run if given incorrect values.

        	setArgs([value]);
        	return this;
        }
        
        /**
         * Use <code>args()</code> to define the values or Matchers to expect as
         * arguments when the method (or property) is invoked. 
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("add").args(Number, Number).returns(42);
         * </listing> 
         */
        public function args(... rest):MockingCouverture
        {
            // FIXME this _really_ should check that the method or property accepts the number of matchers given.
            // we can ignore the types of the matchers though, it will fail when run if given incorrect values.
            
            setArgs(rest);
            return this;
        }
        
        /**
         * Use <code>noArgs()</code> to define that arguments are not expected
         * when the method is invoked.  
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("toString").noArgs();
         * </listing> 
         */
        public function noArgs():MockingCouverture
        {
            // FIXME this _really_ should check that the method or property accepts no arguments.
            
            setNoArgs();
            return this;
        }
        
        /**
         * Use <code>anyArgs()</code> to define that the current Expectation 
         * should be invoked for any arguments.
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("arbitrary").anyArgs();
         * 
         * 	instance.arbitrary(1, 2, 3);	
         * </listing> 
         */
        public function anyArgs():MockingCouverture
        {
            setAnyArgs();
            return this;
        }
        
        /**
         * Sets the value to return when the current Expectation is invoked.  
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("toString").returns("[Instance]");
         * 
         * 	trace(instance.toString());
         * 	// "[Instance]" 
         * </listing>
         */
        public function returns(value:*, ...values):MockingCouverture
        {
        	// FIXME first set returns() value wins, should be last.
        
            addReturns.apply(null, [ value ].concat(values));
            return this;
        }
        
        /**
         * Causes the current Expectation to throw the given Error when invoked. 
         * 
         * @example 
         * <listing version="3.0">
         * 	mock(instance).method("explode").throws(new ExplodyError("Boom!"));
         * 	
         * 	try
         * 	{
         * 		instance.explode();
         * 	}
         * 	catch (error:ExplodyError)
         * 	{
         * 		// error handling.
         * 	}
         * </listing>
         */
        public function throws(error:Error):MockingCouverture
        {
            addThrows(error);
            return this;
        }
        
        /**
         * Calls the given Function with the given arguments when the current
         * Expectation is invoked. 
         * 
         * Note: does NOT pass anything from the Invocation to the function. 
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("message").calls(function(a:int, b:int):void {
         * 		trace("message", a, b);
         * 		// "message 1 2"
         * 	}, [1, 2]);
         * </listing> 
         */
        public function calls(fn:Function, args:Array=null):MockingCouverture
        {
            addCalls(fn, args);
            return this;
        }
        
        /**
         * Causes the current Expectation to dispatch the given Event with an 
         * optional delay when invoked. 
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("update").dispatches(new Event("updated"), 300);
         * </listing>
         */
        public function dispatches(event:Event, delay:Number=0):MockingCouverture
        {
            addDispatches(event, delay);
            return this;
        }
        
        /**
         * 
         */
        public function asEventDispatcher():MockingCouverture
        {
            addEventDispatcherStubs();
            return this;
        }
        
        /**
         * Causes the current Expectation to invoke the given Answer subclass. 
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("update").answers(new CustomAnswer());
         * </listing>
         */
        public function answers(answer:Answer):MockingCouverture
        {
    		addAnswer(answer);
        	return this;
        }
        
        //
        //	verification behaviours
        //
        
        /**
         * Sets the current Expectation to expect to be called the given 
         * number of times. 
         * 
         * If the Expectation has not been invoked the correct number of times 
         * when <code>verify()</code> is called then a  VerifyFailedError will 
         * be thrown.
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("say").times(3);
         * 
         * 	instance.say();
         * 	instance.say();
         * 	instance.say();
         * 	
         * 	verify(instance);
         * </listing>
         */
        public function times(n:int):MockingCouverture
        {
            setInvokeCount(lessThanOrEqualTo(n), equalTo(n));
            return this;
        }
        
        /**
         * Sets the current Expectation to expect not to be called. 
         * 
         * If the Expectation has been invoked then when <code>verify()</code> 
         * is called then a  VerifyFailedError will be thrown.
         * 
         * @see #times()
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("deprecatedMethod").never();
         * </listing>
         */
        public function never():MockingCouverture
        {
            return times(0);
        }
        
        /**
         * Sets the current Expectation to expect to be called once.
         * 
         * @see #times()
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("say").once();
         * 
         * 	instance.say();
         * 
         * 	verify(instance);
         * </listing> 
         */
        public function once():MockingCouverture
        {
            return times(1);
        }
        
        /**
         * Sets the current Expectation to expect to be called two times.
         * 
         * @see #times()
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("say").twice();
         * 
         * 	instance.say();
         * 	instance.say();
         * 
         * 	verify(instance);
         * </listing> 
         */
        public function twice():MockingCouverture
        {
            return times(2);
        }
        
        // at the request of Brian LeGros we have thrice()
        /**
         * Sets the current Expectation to expect to be called three times.
         * 
         * @see #times()
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("say").thrice();
         * 
         * 	instance.say();
         * 	instance.say();
         * 	instance.say();
         * 
         * 	verify(instance);
         * </listing>  
         */
        public function thrice():MockingCouverture
        {
            return times(3);
        }
        
        /**
         * Sets the current Expectation to expect to be called at least the 
         * given number of times.
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("say").atLeast(2);
         * 
         * 	instance.say();
         * 	instance.say();
         * 	instance.say();
         * 
         * 	verify(instance);
         * </listing> 
         */
        public function atLeast(n:int):MockingCouverture
        {
            setInvokeCount(greaterThanOrEqualTo(0), greaterThanOrEqualTo(n));
            return this;
        }
        
        /**
         * Sets the current Expectation to expect to be called at most the 
         * given number of times.
         * 
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("say").atMost(2);
         * 
         * 	instance.say();
         * 
         * 	verify(instance);
         * </listing> 
         */
         public function atMost(n:int):MockingCouverture
        {
            setInvokeCount(lessThanOrEqualTo(n), lessThanOrEqualTo(n));
            return this;
        }

		/**
		 * @example
         * <listing version="3.0">
         * 	mock(instance1).method("sort").ordered("execution order sensitive");
         * 	mock(instance2).method("sort").ordered("execution order sensitive");
         * </listing>
		 */        
        public function ordered(group:String=null):MockingCouverture
        {
        	throw new Error("Not Implemented");
            return this;
        }
        
        /**
         * @example
         * <listing version="3.0">
         * 	mock(instance).method("addEventListener").anyArgs().pass();
         * </listing> 
         */
        public function pass():MockingCouverture
        {
            addPassThrough();
            return this;
        }
		
		//
		//	Decorators
		//
		
		public function asHTTPService():HTTPServiceMockingCouvertureDecorator
		{
			if (!(mockolate.target is HTTPService))
			{
				throw new MockolateError(["Mockolate instance is not a HTTPService", [mockolate.target]], this.mockolate, this.mockolate.target);
			}
			
			return new HTTPServiceMockingCouvertureDecorator(this.mockolate);
		}
        
        //
        //	Internal API
        //
        
        /**
         * Gets a copy of the Array of Expectations.
         * 
         * @private
         */
        mockolate_ingredient function get expectations():Array
        {
            return _expectations.slice(0);
        }
        
        /**
         * Finds the first Expectation that returns <code>true</code> for
         * <code>Expectation.eligible(Invocation)</code> with the given Invocation.
         * 
         * @private
         */
        protected function findEligibleExpectation(expectations:Array, invocation:Invocation):Expectation
        {
        	function isEligibleExpectation(expectation:Expectation):Boolean 
        	{
        		return expectation.eligible(invocation);
        	}
        	
        	return detect(expectations, isEligibleExpectation) as Expectation;
        }
        
        /**
         * Finds the first method Expectation that returns <code>true</code> for
         * <code>Expectation.eligible(Invocation)</code> with the given Invocation.
         * 
         * @private  
         */
        protected function findEligibleMethod(invocation:Invocation):Expectation
        {
        	function isMethodExpectation(expectation:Expectation):Boolean 
		    {
		    	return expectation.isMethod;
		    }
        	
        	var expectation:Expectation = findEligibleExpectation(filter(_mockExpectations, isMethodExpectation), invocation);

        	if (!expectation)
        		expectation = findEligibleExpectation(filter(_stubExpectations, isMethodExpectation), invocation); 

        	if (!expectation && this.mockolate.isStrict)
            	throw new InvocationError(
            		["No method Expectation defined for Invocation:{}", [invocation]], 
            		invocation, this.mockolate, this.mockolate.target);
        	
        	return expectation;
        }

        /**
         * Finds the first property Expectation that returns <code>true</code> for
         * <code>Expectation.eligible(Invocation)</code> with the given Invocation.
         * 
         * @private
         */
        protected function findEligibleProperty(invocation:Invocation):Expectation
        {
        	function isPropertyExpectation(expectation:Expectation):Boolean 
        	{
        		return expectation.isProperty;
        	}
        
        	var expectation:Expectation = findEligibleExpectation(filter(_mockExpectations, isPropertyExpectation), invocation);

        	if (!expectation)
        		expectation = findEligibleExpectation(filter(_stubExpectations, isPropertyExpectation), invocation); 
        	
        	if (!expectation && this.mockolate.isStrict)
            	throw new InvocationError(
            		["No property Expectation defined for Invocation:{}", [invocation]],
            		invocation, this.mockolate, this.mockolate.target);
        	
        	return expectation;
 
        }
        
        /**
         * Called when a method or property is invoked on an instance created by 
         * Mockolate.  
         * 
         * @private
         */
        override mockolate_ingredient function invoked(invocation:Invocation):void
        {
            // FIXME move to constructor
            var invokedAs:Object = {};
            invokedAs[ InvocationType.METHOD ] = invokedAsMethod;
            invokedAs[ InvocationType.GETTER ] = invokedAsGetter;
            invokedAs[ InvocationType.SETTER ] = invokedAsSetter;
            
            invokedAs[ invocation.invocationType ](invocation);
        }
        
        /**
         * Find and invoke the first eligible method Expectation. 
         * 
         * @private
         */
        protected function invokedAsMethod(invocation:Invocation):void
        {
        	// when the invocation is for an IEventDispatcher method
        	// then call that method on the _eventDispatcher
        	// 
        	// IEventDispatcher methods must to be forwarded to a separate
        	// EventDispatcher instance than the proxied instance in order to
        	// actually dispatch events and avoid recursive stack overflows. 
        	//
        	if (this.mockolate.target is IEventDispatcher
        	    && contains(_eventDispatcherMethods, invocation.name))
        	{
        		if (!_eventDispatcher)
        		{
        			_eventDispatcher = new EventDispatcher(this.mockolate.target);
        		}
        		
        		_eventDispatcher[invocation.name].apply(null, invocation.arguments);	
        	}
        	            
            var expectation:Expectation = findEligibleMethod(invocation);
            if (expectation)
            {
            	expectation.invoke(invocation);	
            }
        }
        
        /**
         * Find and invoke the first eligible property Expectation. 
         * 
         * @private
         */
        protected function invokedAsGetter(invocation:Invocation):void
        {
        	var expectation:Expectation = findEligibleProperty(invocation);
            if (expectation)
            {
            	expectation.invoke(invocation);	
            }
        }
        
        /**
         * Find and invoke the first eligible property Expectation. 
         * 
         * @private
         */
        protected function invokedAsSetter(invocation:Invocation):void 
        {
        	var expectation:Expectation = findEligibleProperty(invocation);
            if (expectation)
            {
            	expectation.invoke(invocation);	
            }
        }
        
        /**
         * Create an Expectation.
         * 
         * @see #createPropertyExpectation
         * @see #createMethodExpectation
         * 
         * @private
         */
        protected function createExpectation(name:String, ns:String=null):Expectation
        {
            var expectation:Expectation = new Expectation();
            expectation.name = name;
//            expectation.namespace = ns;
            return expectation;
        }
        
        /**
         * Create an Expectation for a property.
         * 
         * @private
         */
        protected function createPropertyExpectation(name:String, ns:String=null):void
        {
            _currentExpectation = createExpectation(name, ns);
            _currentExpectation.isMethod = false;
            
            _expectations[_expectations.length] = _currentExpectation;
            
            _expectationsAsMocks
            	? _mockExpectations[_mockExpectations.length] = _currentExpectation
            	: _stubExpectations[_stubExpectations.length] = _currentExpectation;
        }        
        
        /**
         * Create an Expectation for a method.
         * 
         * @private
         */
        protected function createMethodExpectation(name:String, ns:String=null):void
        {
            _currentExpectation = createExpectation(name, ns);
            _currentExpectation.isMethod = true;
            
            _expectations[_expectations.length] = _currentExpectation;

            _expectationsAsMocks
            	? _mockExpectations[_mockExpectations.length] = _currentExpectation
            	: _stubExpectations[_stubExpectations.length] = _currentExpectation;                        
        }
        
        /**
         * @private
         */
        protected function setArgs(args:Array):void
        {   
        	_currentExpectation.argsMatcher = describedAs(
        	    new StringDescription().appendList("", ",", "", args).toString(), 
        	    array(map(args, valueToMatcher)));
        }
        
        /**
         * @private
         */
        protected function setNoArgs():void
        {
            _currentExpectation.argsMatcher = describedAs("", anyOf(nullValue(), emptyArray()));
        }
        
        /**
         * @private
         */
		protected function setAnyArgs():void 
		{
			_currentExpectation.argsMatcher = anything();
		}        
        
        /**
         *
         */
        protected function valueToMatcher(value:*):Matcher
        {
        	  // when the value is RegExp
        	  // then match either a reference to the given RegExp
        	  // or create a Matcher for that RegExp
        	  //
            if (value is RegExp)
            {
                return anyOf(equalTo(value), re(value as RegExp));
            }
            
            // when the value is a Date
            // then match the Date by reference
            // or match the Date using dateEqual()
            //
            if (value is Date)
            {
                return anyOf(equalTo(value), dateEqual(value));
            }
            
            // when explicitly given a Class
            // then match either the Class reference or an instance of that Class.
            // 
            // eg: mock(instance).property("enabled").arg(Boolean);
            //
            // if the test should be more exact then the user must supply a value
            // or matcher instance instead.
            // 
            if (value is Class)
            {
            	return anyOf(equalTo(value), instanceOf(value))
            }
            
            // when the value is a Matcher
            // then leave it as is.
            //
            if (value is Matcher)
            {
                return value as Matcher;
            }
            
            // otherwise match by ==
            //
            return equalTo(value);
        }
        
        // FIXME rename setReceiveCount to something better
        /**
         * @private
         */
        protected function setInvokeCount(
            eligiblityMatcher:Matcher, 
            verificationMatcher:Matcher):void
        {
            _currentExpectation.invokeCountEligiblityMatcher = eligiblityMatcher;
            _currentExpectation.invokeCountVerificationMatcher = verificationMatcher;
        }
        
        /**
         * @private
         */
        protected function addAnswer(answer:Answer):void
        {
        	if (answer)
            	_currentExpectation.addAnswer(answer);
        }
        
        /**
         * @private
         */
        protected function addThrows(error:Error):void
        {
            addAnswer(new ThrowsAnswer(error));
        }
        
        /**
         * @private
         */
        protected function prepareEventDispatcher():void 
        {
        	if (!(this.mockolate.target is IEventDispatcher))
        		throw new MockolateError(["Mockolate target is not an IEventDispatcher, target: {}", [mockolate.target]], mockolate, mockolate.target);
        	
        	if (!_eventDispatcher)
        		_eventDispatcher = new EventDispatcher(this.mockolate.target);
        }
        
        /**
         * @private
         */
        protected function addDispatches(event:Event, delay:Number=0):void
        {
        	prepareEventDispatcher();
            addAnswer(new DispatchesEventAnswer(_eventDispatcher, event, delay));
        }
        
        /**
         * @private 
         */
        protected function addEventDispatcherStubs():void 
        {
            prepareEventDispatcher();
            
            for each (var methodName:String in _eventDispatcherMethods)
            {
                stub().method(methodName).answers(new MethodInvokingAnswer(_eventDispatcher, methodName));    
            }
        }
        
        /**
         * @private
         */
        protected function addCalls(fn:Function, args:Array=null):void
        {
            addAnswer(new CallsAnswer(fn, args));
        }
        
        /**
         * @private
         */
        protected function addReturns(value:*, ...values):void
        {
            addAnswer(new ReturnsAnswer([ value ].concat(values)));
        }
        
        /**
         * @private 
         */
        protected function addPassThrough():void 
        {
            addAnswer(new PassThroughAnswer());
        }
        
        /**
         * @private
         */
        override mockolate_ingredient function verify():void
        {
        	// mock expectations are always verified
        	
        	var unmetExpectations:Array = reject(_mockExpectations, verifyExpectation);
        	if (!empty(unmetExpectations))
        	{
        	    var message:String = unmetExpectations.length.toString();
        	    
        	    message += unmetExpectations.length == 1 
        	        ? " unmet Expectation"
        	        : " unmet Expectations";

                for each (var expectation:Expectation in unmetExpectations)
                {
                    message += "\n\t";
                    // TODO move to mockolate.targetClassName
                    message += getQualifiedClassName(this.mockolate.targetClass);
                    
                    if (this.mockolate.name)
                        message += "<\"" + this.mockolate.name + "\">";
                    
                    // TOOD include more description from the Expectation
                    message += expectation.toString();
                }
        	    
        	    throw new ExpectationError(
        	        message, 
        	        unmetExpectations, 
        	        this.mockolate, 
        	        this.mockolate.target);
        	}
        	
        	map(_mockExpectations, verifyExpectation);
        	
        	// stub expectations are not verified
        }   
        
        /**
         * @private 
         */
        protected function verifyExpectation(expectation:Expectation):Boolean 
        {
            if (expectation.invokeCountVerificationMatcher 
        		&& !expectation.invokeCountVerificationMatcher.matches(expectation.invokedCount))
        		return false;
        		
            return true;
        }
    }
}
