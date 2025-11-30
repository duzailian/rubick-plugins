<template>
  <div id="app">
    <div class="search-container" v-show="!showDetail">
      <input
        type="text"
        v-model="keyword"
        placeholder="输入命令搜索 (例如: ls, tar, grep)..."
        ref="searchInput"
        @input="handleSearch"
      >
    </div>

    <div class="list-container" v-show="!showDetail">
      <!-- 热门推荐 -->
      <div v-if="showHotCommands && !keyword" class="hot-commands">
        <h3>热门命令</h3>
        <div class="hot-commands-list">
          <div
            class="hot-command-item"
            v-for="cmd in hotCommands"
            :key="cmd.n"
            @click="viewDetail(cmd.n)"
          >
            <div class="cmd-name">{{ cmd.n }}</div>
            <div class="cmd-desc">{{ cmd.d }}</div>
          </div>
        </div>
      </div>

      <!-- 收藏和历史记录 -->
      <div v-if="showCollections && !keyword" class="collections-section">
        <div class="collection-tabs">
          <button
            :class="{ active: activeTab === 'favorites' }"
            @click="activeTab = 'favorites'"
          >
            收藏 ({{ favorites.length }})
          </button>
          <button
            :class="{ active: activeTab === 'history' }"
            @click="activeTab = 'history'"
          >
            历史记录 ({{ history.length }})
          </button>
        </div>

        <div v-if="activeTab === 'favorites' && favorites.length > 0" class="collection-list">
          <div
            class="command-item favorite"
            v-for="cmd in favorites"
            :key="cmd.n"
            @click="viewDetail(cmd.n)"
          >
            <div class="cmd-name">{{ cmd.n }}</div>
            <div class="cmd-desc">{{ cmd.d }}</div>
            <div class="favorite-btn" @click.stop="toggleFavorite(cmd.n)">
              ★
            </div>
          </div>
        </div>

        <div v-if="activeTab === 'history' && history.length > 0" class="collection-list">
          <div
            class="command-item"
            v-for="cmd in history"
            :key="cmd.n"
            @click="viewDetail(cmd.n)"
          >
            <div class="cmd-name">{{ cmd.n }}</div>
            <div class="cmd-desc">{{ cmd.d }}</div>
          </div>
        </div>
      </div>

      <!-- 搜索结果 -->
      <div v-if="loading" style="text-align:center; padding: 20px; color:#999;">加载数据中...</div>
      <div v-else-if="filteredCommands.length === 0 && keyword" style="text-align:center; padding: 20px; color:#999;">未找到相关命令</div>

      <div
        class="command-item"
        v-for="(cmd, index) in visibleCommands"
        :key="cmd.n"
        :class="{ active: activeIndex === index }"
        @click="viewDetail(cmd.n)"
        @mouseenter="activeIndex = index"
      >
        <div class="cmd-name">{{ cmd.n }}</div>
        <div class="cmd-desc">{{ cmd.d }}</div>
        <div
          class="favorite-btn"
          :class="{ favorited: isFavorite(cmd.n) }"
          @click.stop="toggleFavorite(cmd.n)"
        >
          {{ isFavorite(cmd.n) ? '★' : '☆' }}
        </div>
      </div>

      <!-- 虚拟滚动占位符 -->
      <div v-if="filteredCommands.length > visibleCommands.length" class="virtual-scroll-placeholder">
        还有 {{ filteredCommands.length - visibleCommands.length }} 个结果...
      </div>
    </div>

    <div class="detail-container" :class="{ show: showDetail }">
      <div class="detail-header">
        <div class="back-btn" @click="goBack">← 返回搜索列表</div>
        <div class="detail-actions">
          <button
            class="favorite-btn"
            :class="{ favorited: isFavorite(currentCommand) }"
            @click="toggleFavorite(currentCommand)"
          >
            {{ isFavorite(currentCommand) ? '★ 已收藏' : '☆ 收藏' }}
          </button>
        </div>
      </div>
      <div class="markdown-body" v-html="detailHtml"></div>
      <div v-if="detailLoading" style="text-align:center; padding: 50px;">详情加载中...</div>
    </div>
  </div>
</template>

<script>
import { marked } from 'marked'

export default {
  name: 'App',
  data() {
    return {
      allCommands: {}, // 原始数据对象
      commandList: [], // 转换后的数组格式
      keyword: '',
      filteredCommands: [],
      visibleCommands: [], // 虚拟滚动可见的命令
      showDetail: false,
      detailHtml: '',
      detailLoading: false,
      loading: true,
      debugMode: false,
      errorCount: 0,
      currentCommand: '',
      activeIndex: -1,

      // 收藏和历史记录
      favorites: [],
      history: [],
      activeTab: 'favorites',

      // 使用频率统计
      usageStats: {},

      // 虚拟滚动配置
      visibleCount: 20,
      scrollTop: 0,

      // 移动端检测
      isMobile: false
    }
  },
  computed: {
    // 热门命令（基于使用频率）
    hotCommands() {
      const sortedCommands = this.commandList
        .filter(cmd => this.usageStats[cmd.n] > 0)
        .sort((a, b) => this.usageStats[b.n] - this.usageStats[a.n])
        .slice(0, 8);

      // 如果没有使用记录，返回一些常用命令
      if (sortedCommands.length === 0) {
        const commonCommands = ['ls', 'cd', 'pwd', 'cat', 'grep', 'find', 'ps', 'kill'];
        return this.commandList.filter(cmd => commonCommands.includes(cmd.n)).slice(0, 8);
      }

      return sortedCommands;
    },

    // 是否显示热门推荐
    showHotCommands() {
      return this.commandList.length > 0 && !this.keyword;
    },

    // 是否显示收藏和历史记录
    showCollections() {
      return (this.favorites.length > 0 || this.history.length > 0) && !this.keyword;
    }
  },
  mounted() {
    // 检测移动端
    this.detectMobile();

    // 初始化调试信息
    this.initDebug();

    this.initData();
    // 自动聚焦输入框
    this.$nextTick(() => {
      if(this.$refs.searchInput) this.$refs.searchInput.focus();
    });

    // 监听键盘事件
    document.addEventListener('keydown', this.handleKeydown);

    // 监听滚动事件（虚拟滚动）
    document.addEventListener('scroll', this.handleScroll);

    // 监听 Rubick 事件
    if (window.rubick) {
      window.rubick.onPluginEnter(({ type, payload }) => {
        // 如果用户带参数进入，例如 "linux ls"
        if (type === 'text' && payload) {
          this.keyword = payload;
          this.handleSearch();
        }
        this.$refs.searchInput.focus();
      });
    }
  },
  beforeUnmount() {
    // 清理事件监听器
    document.removeEventListener('keydown', this.handleKeydown);
    document.removeEventListener('scroll', this.handleScroll);
  },
  methods: {
    // 检测移动端
    detectMobile() {
      this.isMobile = window.innerWidth <= 768;
      if (this.isMobile) {
        this.visibleCount = 10; // 移动端显示更少的项目
      }
    },

    // 初始化调试工具
    initDebug() {
      if (window.pluginDebug) {
        this.debugMode = window.pluginDebug.isDev;
        window.pluginDebug.debug.log('Debug tools initialized');
      }
    },

    // 错误处理包装器
    safeExecute(name, fn, context = {}) {
      try {
        if (window.pluginDebug) {
          return window.pluginDebug.performanceMonitor.measure(name, fn);
        }
        return fn();
      } catch (error) {
        this.errorCount++;
        if (window.pluginDebug) {
          window.pluginDebug.errorTracker.track(error, {
            method: name,
            ...context
          });
          window.pluginDebug.debug.error(`Error in ${name}:`, error);
        } else {
          console.error(`Error in ${name}:`, error);
        }
        throw error;
      }
    },

    async initData() {
      try {
        // 首先尝试从 localStorage 读取缓存
        const cache = localStorage.getItem('linux_cmd_data');
        const cacheTimestamp = localStorage.getItem('linux_cmd_data_timestamp');
        const isCacheValid = cacheTimestamp && (Date.now() - parseInt(cacheTimestamp)) < 24 * 60 * 60 * 1000; // 24小时缓存

        if (cache && isCacheValid) {
          this.allCommands = JSON.parse(cache);
          this.processData();
          this.loading = false;
        }

        // 无论是否有缓存，都在后台尝试更新一次数据 (Stale-while-revalidate 策略)
        try {
          const res = await fetch('https://unpkg.com/linux-command@latest/dist/data.json');
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          const data = await res.json();
          this.allCommands = data;
          localStorage.setItem('linux_cmd_data', JSON.stringify(data));
          localStorage.setItem('linux_cmd_data_timestamp', Date.now().toString());

          if (!cache || !isCacheValid) {
            this.processData();
            this.loading = false;
          }
        } catch (fetchError) {
          console.log('网络数据加载失败，尝试使用本地离线数据', fetchError);

          // 如果网络失败，尝试加载本地离线数据
          await this.loadLocalData();

          // 如果本地数据加载成功，处理数据
          if (Object.keys(this.allCommands).length > 0) {
            this.processData();
            this.loading = false;
          } else if (!this.commandList.length) {
            // 如果本地数据也没有，抛出错误
            throw new Error('无法加载任何数据源');
          }
        }

        // 加载用户数据
        this.loadUserData();

      } catch (e) {
        console.error('加载数据失败', e);
        this.loading = false;
        if(!this.commandList.length) {
          this.detailHtml = '<h3>加载数据失败，请检查网络连接或确保已包含离线数据文件。</h3>';
        }
      }
    },

    // 加载本地离线数据
    async loadLocalData() {
      try {
        // 尝试加载本地数据文件
        const response = await fetch('./data.json');
        if (response.ok) {
          const localData = await response.json();
          this.allCommands = localData; // 完全使用本地数据
          console.log('成功加载本地离线数据');
          return true;
        } else {
          console.log('本地数据文件不存在或无法访问');
          return false;
        }
      } catch (error) {
        console.log('本地数据文件加载失败:', error);
        return false;
      }
    },

    // 加载用户数据（收藏、历史、使用统计）
    loadUserData() {
      try {
        this.favorites = JSON.parse(localStorage.getItem('linux_cmd_favorites') || '[]');
        this.history = JSON.parse(localStorage.getItem('linux_cmd_history') || '[]');
        this.usageStats = JSON.parse(localStorage.getItem('linux_cmd_usage_stats') || '{}');
      } catch (error) {
        console.error('加载用户数据失败', error);
      }
    },

    // 保存用户数据
    saveUserData() {
      try {
        localStorage.setItem('linux_cmd_favorites', JSON.stringify(this.favorites));
        localStorage.setItem('linux_cmd_history', JSON.stringify(this.history));
        localStorage.setItem('linux_cmd_usage_stats', JSON.stringify(this.usageStats));
      } catch (error) {
        console.error('保存用户数据失败', error);
      }
    },

    processData() {
      // data.json 结构通常为 { "ls": { "n": "ls", "d": "描述", ... }, ... }
      this.commandList = Object.values(this.allCommands);
      this.filteredCommands = this.commandList;
      this.updateVisibleCommands();
    },

    // 更新可见命令（虚拟滚动）
    updateVisibleCommands() {
      this.visibleCommands = this.filteredCommands.slice(0, this.visibleCount);
    },

    // 处理滚动事件
    handleScroll() {
      if (this.showDetail) return;

      const scrollTop = document.documentElement.scrollTop || document.body.scrollTop;
      const scrollHeight = document.documentElement.scrollHeight || document.body.scrollHeight;
      const clientHeight = document.documentElement.clientHeight || document.body.clientHeight;

      // 接近底部时加载更多
      if (scrollTop + clientHeight >= scrollHeight - 100) {
        this.loadMoreCommands();
      }
    },

    // 加载更多命令
    loadMoreCommands() {
      const currentLength = this.visibleCommands.length;
      if (currentLength < this.filteredCommands.length) {
        const newCommands = this.filteredCommands.slice(currentLength, currentLength + this.visibleCount);
        this.visibleCommands = [...this.visibleCommands, ...newCommands];
      }
    },

    handleSearch() {
      const k = this.keyword.toLowerCase().trim();
      if (!k) {
        this.filteredCommands = this.commandList;
        this.updateVisibleCommands();
        return;
      }

      // 改进搜索：优先匹配命令名，然后匹配描述
      this.filteredCommands = this.commandList.filter(item => {
        if (!item.n && !item.d) return false;

        const nameMatch = item.n && item.n.toLowerCase().includes(k);
        const descMatch = item.d && item.d.toLowerCase().includes(k);

        return nameMatch || descMatch;
      }).sort((a, b) => {
        // 优先显示命令名完全匹配的结果
        const aNameExact = a.n && a.n.toLowerCase() === k;
        const bNameExact = b.n && b.n.toLowerCase() === k;

        if (aNameExact && !bNameExact) return -1;
        if (!aNameExact && bNameExact) return 1;

        // 然后按命令名匹配程度排序
        const aNameStartsWith = a.n && a.n.toLowerCase().startsWith(k);
        const bNameStartsWith = b.n && b.n.toLowerCase().startsWith(k);

        if (aNameStartsWith && !bNameStartsWith) return -1;
        if (!aNameStartsWith && bNameStartsWith) return 1;

        // 最后按使用频率排序
        const aUsage = this.usageStats[a.n] || 0;
        const bUsage = this.usageStats[b.n] || 0;

        return bUsage - aUsage;
      });

      this.updateVisibleCommands();
      this.activeIndex = -1;
    },

    async viewDetail(cmdName) {
      this.showDetail = true;
      this.detailLoading = true;
      this.detailHtml = '';
      this.currentCommand = cmdName;

      try {
        // 记录使用历史
        this.recordUsage(cmdName);

        // 记录历史记录
        this.addToHistory(cmdName);

        let markdownContent = '';

        // 首先尝试从本地加载
        try {
          const localResponse = await fetch(`./command/${cmdName}.md`);
          if (localResponse.ok) {
            markdownContent = await localResponse.text();
            console.log('成功从本地加载命令详情:', cmdName);
          } else {
            throw new Error('Local file not found');
          }
        } catch (localError) {
          // 本地文件不存在，尝试从网络加载
          console.log('本地文件不存在，尝试从网络加载:', cmdName);
          try {
            const res = await fetch(`https://raw.githubusercontent.com/jaywcjlove/linux-command/master/command/${cmdName}.md`);
            if (!res.ok) throw new Error('Not found');
            markdownContent = await res.text();
            console.log('成功从网络加载命令详情:', cmdName);
          } catch (networkError) {
            // 网络也失败，显示友好的错误信息
            console.log('网络加载也失败，显示默认信息:', cmdName);
            markdownContent = `# ${cmdName}\n\n## 命令说明\n\n该命令的详细文档暂时无法加载。\n\n## 离线使用说明\n\n为了获得完整的离线体验，请确保已包含完整的离线数据文件。\n\n## 基本用法\n\n请参考其他在线资源获取该命令的详细使用方法。`;
          }
        }

        // 渲染 Markdown
        this.detailHtml = marked.parse(markdownContent);
      } catch (e) {
        console.error('加载详情失败:', e);
        this.detailHtml = '<h3>加载详情失败或命令文档不存在。</h3>';
      } finally {
        this.detailLoading = false;
      }
    },

    // 记录命令使用频率
    recordUsage(cmdName) {
      this.usageStats[cmdName] = (this.usageStats[cmdName] || 0) + 1;
      this.saveUserData();
    },

    // 添加到历史记录
    addToHistory(cmdName) {
      // 移除重复项
      this.history = this.history.filter(item => item.n !== cmdName);

      // 添加到开头
      const command = this.commandList.find(cmd => cmd.n === cmdName);
      if (command) {
        this.history.unshift(command);

        // 限制历史记录数量
        if (this.history.length > 20) {
          this.history = this.history.slice(0, 20);
        }

        this.saveUserData();
      }
    },

    // 检查是否收藏
    isFavorite(cmdName) {
      return this.favorites.some(cmd => cmd.n === cmdName);
    },

    // 切换收藏状态
    toggleFavorite(cmdName) {
      if (this.isFavorite(cmdName)) {
        // 取消收藏
        this.favorites = this.favorites.filter(cmd => cmd.n !== cmdName);
      } else {
        // 添加收藏
        const command = this.commandList.find(cmd => cmd.n === cmdName);
        if (command) {
          this.favorites.unshift(command);
        }
      }
      this.saveUserData();
    },

    handleKeydown(event) {
      // 只在搜索列表页面处理键盘导航
      if (this.showDetail) {
        // 在详情页面，ESC 键返回
        if (event.key === 'Escape') {
          this.goBack();
          event.preventDefault();
        }
        return;
      }

      // 在搜索列表页面的键盘导航
      switch (event.key) {
        case 'ArrowDown':
          // 向下选择下一个命令
          event.preventDefault();
          if (this.activeIndex < this.visibleCommands.length - 1) {
            this.activeIndex++;
          }
          break;
        case 'ArrowUp':
          // 向上选择上一个命令
          event.preventDefault();
          if (this.activeIndex > 0) {
            this.activeIndex--;
          }
          break;
        case 'Enter':
          // 如果选中了某个命令，打开详情
          if (this.activeIndex >= 0 && this.activeIndex < this.visibleCommands.length) {
            this.viewDetail(this.visibleCommands[this.activeIndex].n);
            event.preventDefault();
          }
          // 如果搜索结果只有一个，直接打开
          else if (this.filteredCommands.length === 1) {
            this.viewDetail(this.filteredCommands[0].n);
            event.preventDefault();
          }
          break;
        case 'Escape':
          // 清空搜索框
          this.keyword = '';
          this.handleSearch();
          event.preventDefault();
          break;
      }
    },
    goBack() {
      this.showDetail = false;
      this.$nextTick(() => {
        this.$refs.searchInput.focus();
      });
    }
  }
}
</script>

<style>
body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; background-color: #f5f5f5; color: #333; }
#app { display: flex; flex-direction: column; height: 100vh; }

/* 搜索栏样式 */
.search-container { padding: 10px; background: #fff; box-shadow: 0 2px 4px rgba(0,0,0,0.1); position: sticky; top: 0; z-index: 10; }
input { width: 100%; padding: 10px; font-size: 16px; border: 1px solid #ddd; border-radius: 4px; box-sizing: border-box; outline: none; }
input:focus { border-color: #007bff; }

/* 列表区域 */
.list-container { flex: 1; overflow-y: auto; padding: 10px; }

/* 热门命令样式 */
.hot-commands { margin-bottom: 20px; }
.hot-commands h3 { margin: 0 0 10px 0; font-size: 16px; color: #666; }
.hot-commands-list { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 8px; }
.hot-command-item { background: #fff; padding: 8px; border-radius: 4px; cursor: pointer; transition: background 0.2s; border-left: 3px solid #007bff; }
.hot-command-item:hover { background: #e9ecef; }
.hot-command-item .cmd-name { font-weight: bold; font-size: 14px; color: #007bff; }
.hot-command-item .cmd-desc { color: #666; font-size: 12px; margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

/* 收藏和历史记录样式 */
.collections-section { margin-bottom: 20px; }
.collection-tabs { display: flex; margin-bottom: 10px; border-bottom: 1px solid #ddd; }
.collection-tabs button { padding: 8px 16px; background: none; border: none; cursor: pointer; font-size: 14px; color: #666; border-bottom: 2px solid transparent; }
.collection-tabs button.active { color: #007bff; border-bottom-color: #007bff; }
.collection-list { max-height: 200px; overflow-y: auto; }

/* 命令项样式 */
.command-item { background: #fff; padding: 10px; margin-bottom: 8px; border-radius: 4px; cursor: pointer; transition: background 0.2s; border-left: 4px solid transparent; position: relative; }
.command-item:hover { background: #e9ecef; }
.command-item.active { border-left-color: #007bff; background: #f0f4ff; }
.command-item.favorite { border-left-color: #ffc107; }
.cmd-name { font-weight: bold; font-size: 18px; color: #007bff; }
.cmd-desc { color: #666; font-size: 14px; margin-top: 4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

/* 收藏按钮样式 */
.favorite-btn { position: absolute; right: 10px; top: 50%; transform: translateY(-50%); background: none; border: none; cursor: pointer; font-size: 18px; color: #ccc; transition: color 0.2s; }
.favorite-btn:hover { color: #ffc107; }
.favorite-btn.favorited { color: #ffc107; }

/* 虚拟滚动占位符 */
.virtual-scroll-placeholder { text-align: center; padding: 10px; color: #999; font-size: 14px; }

/* 详情区域 (模态框或覆盖层) */
.detail-container { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: #fff; overflow-y: auto; display: none; padding: 20px; box-sizing: border-box; z-index: 20; }
.detail-container.show { display: block; animation: slideIn 0.2s ease-out; }
.detail-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; padding-bottom: 10px; border-bottom: 1px solid #eee; }
.back-btn { display: inline-block; padding: 8px 16px; background: #007bff; color: #fff; border-radius: 4px; cursor: pointer; font-size: 14px; user-select: none; }
.back-btn:hover { background: #0056b3; }
.detail-actions .favorite-btn { position: static; transform: none; font-size: 14px; padding: 6px 12px; border: 1px solid #ddd; border-radius: 4px; background: #fff; }
.detail-actions .favorite-btn.favorited { background: #fff3cd; border-color: #ffc107; color: #856404; }

/* Markdown 样式微调 */
.markdown-body { font-size: 15px; line-height: 1.6; max-width: 800px; margin: 0 auto; }
.markdown-body pre { background: #f6f8fa; padding: 16px; border-radius: 4px; overflow-x: auto; }
.markdown-body code { background: rgba(27,31,35,.05); padding: .2em .4em; border-radius: 3px; font-family: monospace; }
.markdown-body h1, .markdown-body h2 { border-bottom: 1px solid #eaecef; padding-bottom: .3em; }

/* 移动端优化 */
@media (max-width: 768px) {
  .search-container { padding: 8px; }
  input { padding: 8px; font-size: 14px; }
  .list-container { padding: 8px; }
  .command-item { padding: 8px; }
  .cmd-name { font-size: 16px; }
  .cmd-desc { font-size: 13px; }
  .hot-commands-list { grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); }
  .detail-container { padding: 15px; }
  .markdown-body { font-size: 14px; }
}

@keyframes slideIn { from { transform: translateX(100%); } to { transform: translateX(0); } }
</style>
