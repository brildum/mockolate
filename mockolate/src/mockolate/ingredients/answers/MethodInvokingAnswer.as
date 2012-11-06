package mockolate.ingredients.answers
{
    import mockolate.ingredients.Invocation;

	/**
	 * Invokes a method by name on a target object with the arguments from the invocations.
	 * 
	 * @see mockolate.ingredients.MockingCouverture#answers()
	 * 
	 * @example
	 * <listing version="3.0">
	 * 	var target:Object = { 
	 * 		invoked: function(a:int, b:int):void {
	 * 			// do something with args
 	 * 		} 
	 * 	};
	 * 
	 * 	mock(instance).method("example").answers(new MethodInvokingAnswer(target, "invoked"));
	 * 	instance.example(1, 2);
	 * </listing>
	 * 
	 * @author drewbourne
	 */
    public class MethodInvokingAnswer extends MethodReturningAnswer
    {

		/**
		 * @inheritDoc
		 */
        public function MethodInvokingAnswer(target:Object, methodName:String)
        {
            super(target, methodName);
        }

		/**
		 * @inheritDoc
		 */
        override public function invoke(invocation:Invocation):*
        {
            super.invoke(invocation);
            return undefined;
        }
    }
}
