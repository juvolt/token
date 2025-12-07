// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// Minimal ERC20 arayuzu (JVT icin)
interface IERC20Minimal {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// JuVolt StakingRewards V2
/// - Kullanici JVT stake eder
/// - Zaman icinde JVT odulu kazanir
/// - Owner onceden bu kontrata JVT yukler
/// - rewardRate: saniye basina dagitilan JVT miktari
contract StakingRewards {
    IERC20Minimal public immutable stakingToken;   // JVT (stake edilen)
    IERC20Minimal public immutable rewardsToken;   // JVT (odul olarak dagitilan, genelde aynisi)

    address public owner;

    // Saniye basina dagitilan odul miktari (18 decimal JVT)
    uint256 public rewardRate;

    // Odul hesaplamasi icin en son guncelleme zamani
    uint256 public lastUpdateTime;

    // 1 stake token basina birikmis odul (1e18 ölçekli)
    uint256 public rewardPerTokenStored;

    // Kullanici bazli muhasebe
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;          // Kullanici icin claim edilmemis JVT
    mapping(address => uint256) public stakedBalance;    // Kullanici stake miktari

    uint256 public totalStaked;

    // Reentrancy korumasi
    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier updateReward(address account) {
        // once genel rewardPerToken guncellenir
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        // sonra bu hesabin bireysel odul verisi guncellenir
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(address _stakingToken, address _rewardsToken) {
        require(_stakingToken != address(0), "Zero staking token");
        require(_rewardsToken != address(0), "Zero rewards token");

        stakingToken = IERC20Minimal(_stakingToken);
        rewardsToken = IERC20Minimal(_rewardsToken);

        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// Owner gunde kac JVT dagitilacagini burada ayarlar.
    /// Ornek: gunde 1000 JVT dagitmak istiyorsan:
    /// rewardRate = 1000e18 / 86400;
    function setRewardRate(uint256 _rewardRate) external onlyOwner updateReward(address(0)) {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    /// 1 stake token icin birikmis odul
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;

        uint256 timeDelta = block.timestamp - lastUpdateTime;
        // rewardRate * timeDelta => toplam dagitilacak odul
        // bunu totalStaked'e bolersek token basina odul
        return rewardPerTokenStored + (timeDelta * rewardRate * 1e18 / totalStaked);
    }

    /// Hesap bazinda toplam hak edilmiş odul
    function earned(address account) public view returns (uint256) {
        return
            (stakedBalance[account] * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18)
            + rewards[account];
    }

    /// JVT stake et
    function stake(uint256 amount) external lock updateReward(msg.sender) {
        require(amount > 0, "Zero amount");

        totalStaked += amount;
        stakedBalance[msg.sender] += amount;

        require(
            stakingToken.transferFrom(msg.sender, address(this), amount),
            "Stake transfer failed"
        );

        emit Staked(msg.sender, amount);
    }

    /// Stake geri cek (anapara)
    function withdraw(uint256 amount) public lock updateReward(msg.sender) {
        require(amount > 0, "Zero amount");
        require(stakedBalance[msg.sender] >= amount, "Not enough staked");

        totalStaked -= amount;
        stakedBalance[msg.sender] -= amount;

        require(
            stakingToken.transfer(msg.sender, amount),
            "Withdraw transfer failed"
        );

        emit Withdrawn(msg.sender, amount);
    }

    /// Sadece odulu al
    function getReward() public lock updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No reward");

        rewards[msg.sender] = 0;

        require(
            rewardsToken.transfer(msg.sender, reward),
            "Reward transfer failed"
        );

        emit RewardPaid(msg.sender, reward);
    }

    
    /// Acil durum: yanlis token gonderilirse owner geri cekebilsin
    /// NOT: Staking token veya reward token icin kullanmaman daha guven verici.
    function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(stakingToken), "Cannot rescue staking token");
        require(token != address(rewardsToken), "Cannot rescue rewards token");
        require(to != address(0), "Zero address");

        IERC20Minimal(token).transfer(to, amount);
    }

    /// Hem stake'i hem odulu cekip tam cikis
    function exit() external {
        withdraw(stakedBalance[msg.sender]);
        getReward();
    }

}
