from vpskit.subscription import (
    SubscriptionNode,
    SubscriptionProfile,
    render_subscription,
)


def test_render_subscription_outputs_deterministic_line_format():
    profile = SubscriptionProfile(
        name="demo",
        nodes=[
            SubscriptionNode(
                name="primary",
                host="example.com",
                port=443,
                protocol="vless",
            ),
            SubscriptionNode(name="backup", host="backup.example.com", port=8443),
        ],
    )

    assert render_subscription(profile) == (
        "# demo\n"
        "vless://example.com:443#primary\n"
        "vmess://backup.example.com:8443#backup\n"
    )
