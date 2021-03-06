<?php

/*
 * Copyright 2011 Facebook, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @group conduit
 */
class ConduitClient {

  protected $protocol;
  protected $host;
  protected $path;
  protected $traceMode;
  protected $connectionID;

  protected $sessionKey;

  public function getConnectionID() {
    return $this->connectionID;
  }

  public function __construct($uri) {
    $this->protocol = parse_url($uri, PHP_URL_SCHEME);
    $this->host = parse_url($uri, PHP_URL_HOST);
    $this->path = parse_url($uri, PHP_URL_PATH);

    if (!$this->host) {
      throw new Exception("Conduit URI '{$uri}' must include a valid host.");
    }

    $this->path = trim($this->path, '/').'/';
  }

  public function callMethodSynchronous($method, array $params) {
    return $this->callMethod($method, $params)->resolve();
  }

  public function didReceiveResponse($method, $data) {
    if ($method == 'conduit.connect') {
      $this->sessionKey = idx($data, 'sessionKey');
      $this->connectionID = idx($data, 'connectionID');
    }
    return $data;
  }

  public function callMethod($method, array $params) {

    $meta = array();

    if ($this->sessionKey) {
      $meta['sessionKey'] = $this->sessionKey;
    }

    if ($this->connectionID) {
      $meta['connectionID'] = $this->connectionID;
    }

    if ($method == 'conduit.connect') {
      $certificate = idx($params, 'certificate');
      if ($certificate) {
        $token = time();
        $params['authToken'] = $token;
        $params['authSignature'] = sha1($token.$certificate);
      }
      unset($params['certificate']);
    }

    if ($meta) {
      $params['__conduit__'] = $meta;
    }

    $start_time = microtime(true);


    $uri = $this->protocol.'://'.$this->host.'/'.$this->path.$method;
    $data = array(
      'params' => json_encode($params),
      'output' => 'json',
    );

    if ($this->protocol == 'https') {
      $core_future = new HTTPSFuture($uri, $data);
    } else {
      $core_future = new HTTPFuture($uri, $data);
      $core_future->setMethod('POST');
    }

    $conduit_future = new ConduitFuture($core_future);
    $conduit_future->setClient($this, $method);
    $conduit_future->isReady();

    if ($this->getTraceMode()) {
      $future_name = $method;
      $conduit_future->setTraceMode(true);
      $conduit_future->setStartTime($start_time);
      $conduit_future->setTraceName($future_name);
      echo "[Conduit] >>> Send {$future_name}()...\n";
    }

    return $conduit_future;
  }

  public function setTraceMode($mode) {
    $this->traceMode = $mode;
    return $this;
  }

  protected function getTraceMode() {
    if (!empty($this->traceMode)) {
      return true;
    }
    return false;
  }
}
