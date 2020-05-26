if (typeof window.callPhantom === 'function') {
  QUnit.done(function(result) {
    console.log(result)
    console.log('\n' + 'Took ' + result.runtime +  'ms to run ' + result.total + ' tests. ' + result.passed + ' passed, ' + result.failed + ' failed.');

    if (typeof window.callPhantom === 'function') {
      window.callPhantom({
        "name": 'QUnit.done',
        "result": result
      });
    }
  });
}