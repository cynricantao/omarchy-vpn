import importlib.util
from pathlib import Path
import unittest

class BackendTest(unittest.TestCase):
    def test_vpn_profiles_and_escaped_paths(self):
        path = Path(__file__).with_name('backend.py')
        self.assertTrue(path.exists(), 'VPN backend has not been implemented')
        spec = importlib.util.spec_from_file_location('backend', path)
        backend = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(backend)
        raw = ('VPN\\: home:u1:wireguard:activated:wg0:/etc/VPN\\:home.nmconnection\n'
               'Other:u2:vpn:::/etc/other.nmconnection\n'
               'Ethernet:u3:802-3-ethernet:activated:eno1:/etc/ethernet\n'
               'tailscale:u4:tun:activated:tailscale0:/run/tailscale\n')
        profiles = backend.parse_profiles(raw)
        self.assertEqual(len(profiles), 2)
        self.assertEqual(profiles[0]['name'], 'VPN: home')
        self.assertEqual(profiles[0]['file'], '/etc/VPN:home.nmconnection')
        self.assertTrue(profiles[0]['active'])
        self.assertFalse(profiles[1]['active'])

if __name__ == '__main__':
    unittest.main()
