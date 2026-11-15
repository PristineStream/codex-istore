'use strict';
'require view';
'require rpc';
'require dom';

var callStatus = rpc.declare({ object: 'luci.codex-istore', method: 'status' });

var checkStatus = function() {
	return callStatus().then(function(data) {
		if (!data || [ 'installed', 'missing', 'unavailable', 'unsupported' ].indexOf(data.state) < 0 ||
		    typeof data.version !== 'string' || typeof data.platform !== 'string')
			throw new Error('invalid status');
		return data;
	}).catch(function() { return null; });
};

return view.extend({
	load: function() { return checkStatus(); },

	statusContent: function(data) {
		var message = !data ? _('Could not check the installation. Check access to the router and try again.') : {
			installed: _('Installed'),
			missing: _('Not installed'),
			unavailable: _('Installation unavailable. Check that its storage is mounted.'),
			unsupported: _('This device is not supported by this package.')
		}[data.state];

		return [
			E('p', { 'role': 'status' }, [ E('strong', {}, [ message ]) ]),
			data && data.state === 'installed' && data.version ? E('p', {}, [ _('Version'), ': ', data.version ]) : '',
			data && data.platform ? E('p', {}, [ _('Platform'), ': ', data.platform ]) : ''
		];
	},

	render: function(data) {
		var self = this;
		var status = E('div', { 'aria-live': 'polite' }, this.statusContent(data));
		var refresh = E('button', {
			'class': 'cbi-button',
			'type': 'button',
			'click': function() {
				refresh.disabled = true;
				dom.content(status, E('p', { 'role': 'status' }, [ _('Checking installation…') ]));
				checkStatus().then(function(next) {
					dom.content(status, self.statusContent(next));
					refresh.disabled = false;
				});
			}
		}, [ _('Refresh status') ]);

		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, [ _('Codex CLI') ]),
			E('p', {}, [ _('Install and use Codex CLI from an SSH session. This page does not install software or manage sign-in.') ]),
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, [ _('Installation status') ]),
				status,
				refresh
			]),
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, [ _('Get started over SSH') ]),
				E('ol', {}, [
					E('li', {}, [ _('As root, install to a mounted storage volume. Replace <volume> with the volume name:'), E('pre', {}, [ 'codex-istore install /mnt/<volume>' ]) ]),
					E('li', {}, [ _('As the non-root account that will use Codex, sign in with the official device flow:'), E('pre', {}, [ 'codex-istore run login --device-auth' ]), E('p', {}, [ _('Follow the instructions shown in SSH. Device-code authentication must be enabled for your ChatGPT account or workspace. Never share the code.') ]) ]),
					E('li', {}, [ _('In the same non-root account, change to your project directory and start Codex:'), E('pre', {}, [ 'codex-istore run' ]) ])
				]),
				E('p', {}, [ _('Installation status does not indicate whether you are signed in.') ])
			])
		]);
	},
	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
