---
layout: page
title: Preparing and Creating
author: Drew Bourne
---

## Preparing

<!--
_FIXME add a description about why Mockolates need to be prepared_
_FIXME link to the Flavour source_
-->

To prepare the Class you want to create Mockolates for use the `prepare(...classes)` function.
    
{% highlight as3 %}
[Before(async, timeout=5000)]
public function prepareMockolates():void
{
    Async.proceedOnEvent(this,
        prepare(Flavour, DarkChocolate),
        Event.COMPLETE);
}
{% endhighlight %}
    
Mockolates do take some time to prepare so we run this `[Before]` block asynchronously to allow the code generation backend to do its thing. 

See [Writing an Async Test](http://docs.flexunit.org/index.php?title=Writing_an_AsyncTest) in the [FlexUnit](http://flexunit.org/) [wiki](http://docs.flexunit.org/).

`prepare(Class)` can take more than one Class so go ahead and feed it as many as you like. Just be sure to wait till they are complete. 

## Creating Mockolates nicely, or strictly

Each Mockolate instance operates as either a 'nice' or a 'strict' Mock Object. 

- 'nice' Mock Objects will play nice and return false-y values for methods and properties that aren't mocked or stubbed. 
- 'strict' Mock Objects will whinge and cry if you mistreat them by calling methods that aren't mocked or stubbed. By whinge and cry I mean throw `InvocationError`s. 

Create a nice mock using `nice(Class)`, or a strict Mock using `strict(Class)` giving them the Class you want an instance of.

{% highlight as3 %}
[Test]
public function nicelyPlease():void 
{
    var flavour:Flavour = nice(Flavour);
    
    assertThat(flavour.name, nullValue());
}

[Test(expected="mockolate.errors.InvocationError")]
public function strictlyIfYouMust():void 
{
    var flavour:Flavour = strict(DarkChocolate);
    
    // accessing a property without a mock or stub will cause a strict Mock Object to throw an InvocationError
    var name:String = flavour.name;
}
{% endhighlight %}

## preparing and creating a little bit easier

Mockolate provides both a [FlexUnit Rule](http://docs.flexunit.org/index.php?title=CreatingRules) and a [FlexUnit runner](http://docs.flexunit.org/index.php?title=Runners_and_Builders) that can prepare and create nice and strict Mockolate instances based on metadata. Any public instance variable marked with `[Mock]` metadata will be prepared, and injected. Using the `MockolateRule` or `MockolateRunner` will take care of the asynchronous prepare step and will wait until the classes are prepared before running your tests.

There are two options that can be given to `[Mock]`.

- use `[Mock(type="strict")]` to create a strict Mockolate.
- use `[Mock(inject="false")]` to prepare only, and not create a Mockolate.

By default a nice Mockolate is created and injected. 

Using the `MockolateRule` for FlexUnit 4.1+

{% highlight as3 %}
public class ExampleWithRule
{
    [Rule]
    public var mocks:MockolateRule = new MockolateRule();
    
    [Mock(type="strict")]
    public var strictlyThanks:Example;
    
    [Mock(inject="false")]
    public var prepareButDontCreate:Example;
}
{% endhighlight %}

Using the `MockolateRunner` for FlexUnit 4

{% highlight as3 %}
// import and reference the runner to ensure it is compiled in.
import mockolate.runner.MockolateRunner; 
MockolateRunner; 

[RunWith("mockolate.runner.MockolateRunner")]
public class ExampleWithRunner
{
    [Mock]
    public var nicelyPlease:Example;
    
    [Mock(type="strict")]
    public var strictlyThanks:Example;
    
    [Mock(inject="false")]
    public var prepareButDontCreate:Example;
}
{% endhighlight %}

## next [stubbing and mocking](stubbing_and_mocking.html)